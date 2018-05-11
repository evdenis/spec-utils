#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 6;
use Test::Deep;

use C::Util::Parsing qw(_get_structure_wo_field_names);
use C::StructureSet;

my $set = C::StructureSet->parse(\join('', <DATA>), 'kernel');

my ($struct) = @{$set->set};

cmp_deeply($struct->get_code_tags,
   [['struct', 'sk_buff',], ['struct', 'sock',], ['struct', 'key',], ['struct', 'cred',],], 'tags');
cmp_deeply($struct->get_code_ids, ['security_operations'], 'ids');

is($struct->name, 'security_operations', 'name');
is($struct->type, 'struct', 'type');

is(
   $struct->to_string, 'struct security_operations {
 void (*skb_owned_by) (struct sk_buff *skb, struct sock *sk);
 int (*key_alloc) (struct key *key, const struct cred *cred, unsigned long flags);
 void (*key_free) (struct key *key);
};', 'to_string'
);

is(
   _get_structure_wo_field_names($struct->to_string),
   'struct security_operations {
 void (*) (struct sk_buff *, struct sock *)
 int (*) (struct key *, const struct cred *, unsigned long )
 void (*) (struct key *)
};',
   'to_string without field names'
);

__DATA__

struct security_operations {
 void (*skb_owned_by) (struct sk_buff *skb, struct sock *sk);
 int (*key_alloc) (struct key *key, const struct cred *cred, unsigned long flags);
 void (*key_free) (struct key *key);
};

