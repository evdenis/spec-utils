#!/usr/bin/perl

use Data::Printer;
use common::sense;
use lib './lib';

use C::StructureSet;

my $data = join('', <DATA>);
my $set = C::StructureSet->parse(\$data, 'kernel');

foreach (@{$set->set}) {
   print $_->to_string(undef, 1);
}

__DATA__

struct test {
   int (*a)( int b, int c);
   int b, c, d;
   long long;
   struct {
      int sa;
      int sb;
   } ss;
};

