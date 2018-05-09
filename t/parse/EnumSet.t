#!/usr/bin/perl

use Test::More;
use Test::Deep;

use C::EnumSet;

my $set = C::EnumSet->parse(\join('', <DATA>), 'kernel');

my ($enum) = @{$set->set};

ok($enum->has_name, 'has_name');
is($enum->name, 'pid_type',         'name');
is($enum->head, "enum pid_type\n{", 'head');
is($enum->tail, '};',               'tail');
is($enum->to_string(undef, 1), 'enum pid_type { __STUB__PID_TYPE };', 'stub enum');

cmp_deeply($enum->fields_dependence, [[], [], [], []], 'fields dependence');
cmp_deeply(
   [$enum->fields->as_list],
   [
      'PIDTYPE_PID',  [0, re('^\s*PIDTYPE_PID\s*$'),  'next',],
      'PIDTYPE_PGID', [0, re('^\s*PIDTYPE_PGID\s*$'), 'next',],
      'PIDTYPE_SID',  [0, re('^\s*PIDTYPE_SID\s*$'),  'next',],
      'PIDTYPE_MAX',  [0, re('^\s*PIDTYPE_MAX\s*$'),  'next',],
   ],
   'fields'
);

$enum->up('PIDTYPE_MAX');
cmp_deeply($enum->fields->get('PIDTYPE_MAX'), [1, ignore(), 'next'], 'inc ref');
is($enum->to_string(undef, 1), 'enum pid_type { PIDTYPE_MAX = 3 };', 'last constant');
$enum->up('PIDTYPE_PID');
is(
   $enum->to_string(undef, 1) =~ s/\s++/ /gr,
   "enum pid_type { PIDTYPE_PID, PIDTYPE_MAX = 3 };",
   'first and last constants'
);
$enum->up('PIDTYPE_SID');
is(
   $enum->to_string(undef, 1) =~ s/\s++/ /gr,
   "enum pid_type { PIDTYPE_PID, PIDTYPE_SID = 2, PIDTYPE_MAX };",
   'middle constant'
);

done_testing();

__DATA__

enum pid_type
{
       PIDTYPE_PID,
       PIDTYPE_PGID,
       PIDTYPE_SID,
       PIDTYPE_MAX
}  ;
