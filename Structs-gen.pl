#!/usr/bin/perl

use strict;
use Data::Dumper;

usage($0) unless $#ARGV+1;

my %structs;

foreach my $file (@ARGV) { parse_file($file) };

print Dumper(\%structs);

foreach my $index (keys %structs)
{
	my %ready = generate_struct($structs{$index});
	foreach my $file (keys %ready)
	{
		write_file($file, $ready{$file});
	}
}

sub parse_file()
{
	my $SOURCE = $_[0];
	my $lineno = 0;
	my %one;
	my $line;
	my $h;

	open($h, '<', $SOURCE) or die "File $SOURCE: $!";

	while( defined($line = readline($h) ) )
	{
		$line =~ s/^[ \r\n\t]+//;
		$line =~ s/[ \r\n\t]+$//;
		$line =~ s/[ \r\n\t]+/ /g;

		if ($line =~ /^struct ([^ ]+) \{/)
		{
			print "%struct($1) start\n";
			%one = (
				name => $1,
				fields => [],
				comments => [],
				includes => [],
				methods => [],
				source => $SOURCE,
			);
			next;
		}

		if ($line =~ /^\}/)
		{
			$structs{$one{name}} = { %one } if %one;
			undef %one;
			next;
		}

		if ($line =~ /^field ([^ ]+) ([^ ;]+)/)
		{
			my %field = (
				name => $2,
				type => $1
			);
			push @{one{fields}}, \%field;

			next;
		}

		if ($line =~ /^(#include.*)/)
		{
			push @{one{includes}}, $1;
		}
	}
	close($h);

	# fail-safe
	$structs{$one{name}} = { %one } if %one;
	undef %one;
}

sub generate_struct($)
{
	my %struct = %{$_[0]};
	my %auto_inc;
	my $auto =
qq{//
// This file is automaticaly generated from $struct{source}
//
};

	my $fields_def = join("\n\t", map {
		$auto_inc{$_->{type}} = 1 if defined($structs{$_->{type}});
		"$_->{type} $_->{name};"
	} @{$struct{fields}});

	my $header = $auto
		.join("\n", @{$struct{includes}})
		.join("\n", map { get_include_type($_) } keys %auto_inc)
		.qq{

struct $struct{name} \{
	$fields_def

	$struct{name}();
	$struct{name}(const $struct{name}& rhs);
	virtual ~$struct{name}() {}

	$struct{name}& operator=(const $struct{name}& rhs);

	bool operator<(const $struct{name}& rhs) const;
	bool operator>(const $struct{name}& rhs) const;
	bool operator==(const $struct{name}& rhs) const;
	bool operator!=(const $struct{name}& rhs) const;
	void swap($struct{name}& rhs);
\};
};

	my $body;

	return (
		$struct{name}.".h" => $header,
		$struct{name}.".cpp" => $body,
	)
}

sub usage($)
{
	my $msg =
qq{C++ struct generator
Usage: $_[0] Structs.gen

};
	die "$msg";
}

sub write_file($:$)
{
	my ($file, $data) = @_;
	my $h;

	print "Writing $file ... ";
	open($h, ">$file") or die " ERROR: $!";
	print $h $data;
	close($h);
	print "ok\n";
}

sub get_include_type($)
{
	"#include \"$_[0].h\""
}
