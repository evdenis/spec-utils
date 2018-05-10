#!/usr/bin/perl

use Test::More tests => 15;
use Test::Deep;

use C::EnumSet;

my $set = C::EnumSet->parse(\join('', <DATA>), 'kernel');

my ($enum) = @{$set->set};

cmp_deeply($enum->get_code_tags, ['FSCW'], 'tags');
cmp_deeply($enum->get_code_ids, [qw(TEST1 TEST12 TEST2 TEST3 TEST4 TEST5 TEST6 TEST7)], 'ids');

ok(!$enum->has_name, '!has_name');
is($enum->name, '',       'void name');
is($enum->head, 'enum {', 'head');
is($enum->tail, '};',     'tail');
is(
   $enum->to_string(undef, 0), 'enum {
   TEST1,
   TEST12 = 10,
   TEST2 = TEST1 + 3,
   TEST3 = TEST2 + 1,
   TEST4,
   TEST5,
   TEST6 = $FSCW#$@,
   TEST7
};', 'original enum'
);

is($enum->to_string(undef, 1), undef, 'undef in case of unused enum');

cmp_deeply(
   $enum->fields_dependence,
   [[], [0], [1, 0], [0, 0, 1], [0, 0, 1], [0, 0, 1], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0]],
   'fields dependence'
);

cmp_deeply(
   [$enum->fields->as_list],
   [
      "TEST1",  [0, "\n   TEST1",             "next"],
      "TEST12", [0, "\n   TEST12 = 10",       "value", "10"],
      "TEST2",  [0, "\n   TEST2 = TEST1 + 3", "expr", "TEST1 + 3"],
      "TEST3",  [0, "\n   TEST3 = TEST2 + 1", "expr", "TEST2 + 1"],
      "TEST4",  [0, "\n   TEST4",             "next"],
      "TEST5",  [0, "\n   TEST5",             "next"],
      "TEST6", [0, "\n   TEST6 = " . '$FSCW#$@', "expr", '$FSCW#$@'],
      "TEST7", [0, "\n   TEST7\n", "next"]
   ],
   'fields'
);

$enum->up('TEST5');
cmp_deeply($enum->fields->get('TEST5'), [1, ignore(), 'next'], 'inc ref');
is(
   $enum->to_string(undef, 1) =~ s/\s++/ /gr,
   "enum { TEST1, TEST2 = TEST1 + 3, TEST5 = TEST2 + 1 + 2 };",
   'TEST5 constant'
);

$enum->up('TEST2');
cmp_deeply($enum->fields->get('TEST2'), [2, ignore(), 'expr', "TEST1 + 3"], 'inc expr ref');
is(
   $enum->to_string(undef, 1) =~ s/\s++/ /gr,
   "enum { TEST1, TEST2 = TEST1 + 3, TEST5 = TEST2 + 1 + 2 };",
   'TEST2 && TEST5 constant'
);

$enum->up('TEST7');
is(
   $enum->to_string(undef, 1) =~ s/\s++/ /gr,
   'enum { TEST1, TEST2 = TEST1 + 3, TEST5 = TEST2 + 1 + 2, TEST7 = $FSCW#$@ + 1 };',
   'TEST2 && TEST5 && TEST7 constant'
);

__DATA__

enum {
   TEST1,
   TEST12 = 10,
   TEST2 = TEST1 + 3,
   TEST3 = TEST2 + 1,
   TEST4,
   TEST5,
   TEST6 = $FSCW#$@,
   TEST7
};

