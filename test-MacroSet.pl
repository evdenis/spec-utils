#!/usr/bin/perl

use Data::Printer;

use common::sense;

use lib "./lib";

use C::MacroSet;

my @m = <DATA>;
my $set = C::MacroSet->parse(\@m, 'kernel');

$set = $set->set;

p $set;

__DATA__
	#define D(fmt,arg...)
	#define d(x)
	#define nd(x) x
#define __lockfunc __attribute__((section(".spinlock.text")))
