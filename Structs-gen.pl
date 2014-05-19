#!/usr/bin/perl

use strict;
use Data::Dumper;

my %options = (
	namespace => "",
	#namespace => "foospace",

	# pragma|define
	includeonce => "pragma",
	#includeonce => "define",
);

usage($0) unless $#ARGV+1;

my %structs;

foreach my $file (@ARGV) { parse_file($file) };

print Dumper(\%structs);

foreach my $index (sort { $a cmp $b } keys %structs)
{
	my %ready = generate($structs{$index});
	foreach my $file (sort { $a cmp $b } keys %ready)
	{
		write_file($file, $ready{$file});
	}
}

sub generate($)
{
	my %struct = %{$_[0]};

	return generate_struct(\%struct) if $struct{type} eq 'struct';
	return generate_vector(\%struct) if $struct{type} eq 'vector';

	()
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
				type => 'struct',
				fields => [],
				comments => [],
				includes => [],
				methods => [],
				source => $SOURCE,
			);
			next;
		}

		if ($line =~ /^vector ([^ ]+) : ([^; ]+)/)
		{
			print "%vector($1)\n";
			my %v = (
				name => $1,
				value => $2,
				type => 'vector',
				comments => [],
				includes => [],
				source => $SOURCE,
			);
			$structs{$v{name}} = { %v };
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

	my $fields_def = join("\n\t", map {
		$auto_inc{$_->{type}} = 1 if defined($structs{$_->{type}});
		"$_->{type} $_->{name};"
	} @{$struct{fields}});

	my $init_fields_default;

	my $header = ""
		.get_include_single_start(\%struct)
		.get_auto_comment(\%struct)
		.join("\n", @{$struct{includes}})
		.join("\n", map { get_include_type($_) } keys %auto_inc)
		.get_namespace_start(\%struct)
		.qq{

struct $struct{name}
\{
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
}
		.get_namespace_stop(\%struct)
		.get_include_single_stop(\%struct)
		;

	my $body = ""
		.get_auto_comment(\%struct)
		.get_namespace_start(\%struct)
.qq{
$struct{name}::$struct{name}()
	$init_fields_default
{
}

$struct{name}::$struct{name}(const $struct{name}& rhs)
{
}

$struct{name}& $struct{name}::operator=(const $struct{name}& rhs)
{
}

bool $struct{name}::operator<(const $struct{name}& rhs) const
{
}

bool $struct{name}::operator>(const $struct{name}& rhs) const
{
}

bool $struct{name}::operator==(const $struct{name}& rhs) const
{
}

bool $struct{name}::operator!=(const $struct{name}& rhs) const
{
}

void $struct{name}::swap($struct{name}& rhs)
{
}

}
		.get_namespace_stop(\%struct)
		;

	return (
		get_file_name_header(\%struct) => $header,
		get_file_name_source(\%struct) => $body,
	)
}

sub generate_vector($)
{
	my %struct = %{$_[0]};
	my %auto_inc = (
		$struct{value} => 1,
	);

	my $header = ""
		.get_include_single_start(\%struct)
		.get_auto_comment(\%struct)
		.join("\n", map { get_include_type($_) } keys %auto_inc)
		.get_namespace_start(\%struct)
		.qq{
#include <vector>

typedef std::vector<$struct{value}> $struct{name};
}
		.get_namespace_stop(\%struct)
		.get_include_single_stop(\%struct)
		;

	return (
		get_file_name_header(\%struct) => $header,
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

sub get_include_type_path($)
{
	$_[0].".h"
}

sub get_include_type($)
{
	"#include \"".get_include_type_path($_[0])."\""
}

sub get_auto_comment($)
{
	my %struct = %{$_[0]};

qq{//
// This file is automaticaly generated from $struct{source}
//
};
}

sub get_file_name_header($)
{
	my %struct = %{$_[0]};

	$struct{name}.".h"
}

sub get_file_name_source($)
{
	my %struct = %{$_[0]};

	$struct{name}.".cpp"
}

sub get_include_single_mark($)
{
	my %struct = %{$_[0]};
	my $mark = "STRUCTGEN_"
		.$options{namespace}
		."_"
		.get_include_type_path($struct{name})
		."_INDLUDED";
	$mark =~ s/[^a-zA-Z0-0_]/_/g;

	$mark
}


sub get_include_single_start($)
{
	my %struct = %{$_[0]};

	return "#pragma once\n\n" if $options{includeonce} eq "pragma";

	my $mark = get_include_single_mark(\%struct);

qq{#ifndef $mark
#define $mark

}

}

sub get_include_single_stop($)
{
	my %struct = %{$_[0]};

	return "" if $options{includeonce} eq "pragma";

	my $mark = get_include_single_mark(\%struct);

qq{
#endif // #ifndef $mark
}

}

sub get_namespace_start($)
{
	my %struct = %{$_[0]};

	return "" if length($options{namespace}) < 1;

	"\n\nnamespace $options{namespace}\n{\n"
}

sub get_namespace_stop($)
{
	my %struct = %{$_[0]};

	return "" if length($options{namespace}) < 1;

	"\n\n} // namespace $options{namespace}\n\n"
}
