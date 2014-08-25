#!/usr/bin/perl

use Data::Printer;

use common::sense;

use lib "./lib";

use C::TypedefSet;

my $set = C::TypedefSet->parse(\join('', <DATA>), 'kernel');

my $set = $set->set;

p $set;

__DATA__

typedef int proc_handler (struct ctl_table *ctl, int write,
                           void __user *buffer, size_t *lenp, loff_t *ppos);

