#!/usr/bin/perl

use Data::Printer;
use common::sense;
use lib './lib';
use C::Util::Parsing qw(_get_structure_wo_field_names);

use C::StructureSet;

my $data = join('', <DATA>);
my $set = C::StructureSet->parse(\$data, 'kernel');

foreach (@{$set->set}) {
   print _get_structure_wo_field_names($_->code);
}

__DATA__


struct security_operations {
 void (*skb_owned_by) (struct sk_buff *skb, struct sock *sk);
 int (*key_alloc) (struct key *key, const struct cred *cred, unsigned long flags);
 void (*key_free) (struct key *key);
};

