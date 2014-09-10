#!/usr/bin/perl

use Data::Printer;
use common::sense;
use lib::abs '../lib';

use Local::C::Parsing qw/_get_structure_wo_field_names _get_structure_fields/;

my $data = join('', <DATA>);

my $str    = _get_structure_wo_field_names($data);
my $fields = _get_structure_fields($data);

p $str;
p $fields;


__DATA__

struct test {
   int (*a)( int b, int c);
   int b, c, d;
   long long;
};

