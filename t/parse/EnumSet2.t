#!/usr/bin/perl

use Test::More;

use C::EnumSet;

my $set = C::EnumSet->parse(\join('', <DATA>), 'kernel');

my ($fst, $snd) = @{$set->set};

is($fst->to_string(undef, 1), 'enum pid_type { __STUB__PID_TYPE };', "unused enum");

#   $_->up('TEST5');
#   $_->up('PIDTYPE_PID');
#   $_->up('PIDTYPE_MAX');
#   $_->up('TEST7');

#print $_->to_string(undef, 1);

__DATA__

enum {
   TEST1,
   TEST12,
   TEST2 = TEST1 + 3,
   TEST3 = TEST2 + 1,
   TEST4,
   TEST5,
   TEST6 = $FSCW#$@,
   TEST7
};

enum pid_type
{
       PIDTYPE_PID,
       PIDTYPE_PGID,
       PIDTYPE_SID,
       PIDTYPE_MAX
}  ;
