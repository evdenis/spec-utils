#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 2;
use Test::Deep;
use C::Util::Parsing qw(_get_structure_wo_field_names _get_structure_fields);

my $data = join('', <DATA>);

is(
   _get_structure_wo_field_names($data),
   "struct test {\n   int (*)( int , int )\n   int , , \n   long \n};\n",
   '_get_structure_wo_field_names'
);
cmp_deeply(_get_structure_fields($data), ["a", "b", "c", "b", "c", "d", "long"], '_get_structure_fields');

__DATA__
struct test {
   int (*a)( int b, int c);
   int b, c, d;
   long long;
};
