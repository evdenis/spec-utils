#!/usr/bin/perl

use Data::Printer;

use common::sense;

use lib::abs '../lib';

use C::EnumSet;
use Scalar::Util qw(blessed);

my $set = C::EnumSet->parse(\join('', <DATA>), 'kernel');


foreach (@{ $set->set }) {
   #p $_;
   #exit;
   #$_->up('TEST12');
   #$_->up('TEST3');
   $_->up('TEST5');
   $_->up('PIDTYPE_PID');
   $_->up('PIDTYPE_MAX');
   #$_->up('TEST7');
   #p $_;
   #p $_->fields;
   print $_->to_string(undef, 1);
   print "\n" . '---' . "\n";
}

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
