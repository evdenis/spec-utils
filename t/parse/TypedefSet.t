#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 4;
use Test::Deep;

use C::TypedefSet;

my $set = C::TypedefSet->parse(\join('', <DATA>), 'kernel');
my $td = @{$set->set}[0];

is($td->name,   'proc_handler', 'name');
is($td->inside, undef,          'inside');
#is($td->type, undef, 'type');

cmp_deeply($td->get_code_ids, ['proc_handler'], 'ids');
cmp_deeply($td->get_code_tags,
   [["struct", "ctl_table"], "ctl", "write", "__user", "buffer", "size_t", "lenp", "loff_t", "ppos"], 'tags');

__DATA__

typedef int proc_handler (struct ctl_table *ctl, int write,
                           void __user *buffer, size_t *lenp, loff_t *ppos);

