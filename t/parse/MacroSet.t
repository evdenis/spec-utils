#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 17;
use Test::Deep;

use C::MacroSet;

my @m = <DATA>;
my $set = C::MacroSet->parse(\@m, 'kernel');

my %macro;
foreach my $m (@{$set->set}) {
   $macro{$m->name} = $m;
}

cmp_deeply([sort keys %macro], [qw(D ENUM __lockfunc current d nd)], 'all macro');

cmp_deeply($macro{d}->args,       [qw(x)],       'single arg test');
cmp_deeply($macro{D}->args,       [qw(fmt arg)], 'two args test');
cmp_deeply($macro{current}->args, [],            'empty args test');
cmp_deeply($macro{__lockfunc}->args, undef, 'wo args test');
cmp_deeply($macro{ENUM}->args,       undef, 'wo args test 2');

is($macro{D}->substitution,          '',                                           'macro void expansion test');
is($macro{nd}->substitution,         'x',                                          'macro simple expansion test');
is($macro{__lockfunc}->substitution, '__attribute__((section(".spinlock.text")))', 'macro expansion test 1');
is($macro{ENUM}->substitution,       'ENUM',                                       'macro expansion test 2');

ok($macro{ENUM}->expands_to_itself,        'expands to itself');
ok(!$macro{__lockfunc}->expands_to_itself, 'not expands to itself');

cmp_deeply($macro{ENUM}->to_string,    '   #define ENUM ENUM', 'to_string 1');
cmp_deeply($macro{current}->to_string, '   #define current()', 'to_string 2');
cmp_deeply(
   $macro{__lockfunc}->to_string,
   '#define __lockfunc __attribute__((section(".spinlock.text")))',
   'to_string 3'
);

cmp_deeply($set->ids, bag(["__lockfunc"], ["nd"], ["D"], ["ENUM"], ["current"], ["d"]), 'ids');
cmp_deeply($set->tags, bag([], ["spinlock", "text"], [], [], [], []), 'tags');

__DATA__
	#define D(fmt,arg...)
	#define d(x)
	#define nd(x) x
   #define current()
#define __lockfunc __attribute__((section(".spinlock.text")))
   #define ENUM ENUM
