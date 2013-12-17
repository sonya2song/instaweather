#!/usr/bin/perl -w

use strict;
use Data::Dumper;

my @keys = qw/a b c/;
my @values = qw/A B C/;
my %hash = ();
%hash{@keys} = @values;
print Dumper %hash;