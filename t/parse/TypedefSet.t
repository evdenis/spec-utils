#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 8;
use Test::Deep;

use C::TypedefSet;

my $set = C::TypedefSet->parse(\join('', <DATA>), 'kernel');

my %g;
$g{$_->name} = $_ foreach @{$set->set};

cmp_deeply([sort keys %g], [qw(coap_option_t proc_handler)], 'globals');

is($g{proc_handler}->inside, undef,   'inside test 1');
is($g{proc_handler}->type,   'empty', 'type test 1');

cmp_deeply($g{coap_option_t}->inside, ['enum'], 'inside test 2');
is($g{coap_option_t}->type, 'enum', 'type test 2');

cmp_deeply($g{proc_handler}->get_code_ids, ['proc_handler'], 'ids test 1');
cmp_deeply(
   $g{proc_handler}->get_code_tags,
   [["struct", "ctl_table"], "ctl", "write", "__user", "buffer", "size_t", "lenp", "loff_t", "ppos"],
   'tags test 1'
);

cmp_deeply($g{coap_option_t}->get_code_tags, [], 'tags test 2');

__DATA__

typedef int proc_handler (struct ctl_table *ctl, int write,
                           void __user *buffer, size_t *lenp, loff_t *ppos);

typedef enum {
  COAP_OPTION_IF_MATCH = 1,
  COAP_OPTION_URI_HOST = 3,
  COAP_OPTION_ETAG = 4,
  COAP_OPTION_IF_NONE_MATCH = 5,
  COAP_OPTION_OBSERVE = 6,
  COAP_OPTION_URI_PORT = 7,
  COAP_OPTION_LOCATION_PATH = 8,
  COAP_OPTION_URI_PATH = 11,
  COAP_OPTION_CONTENT_FORMAT = 12,
  COAP_OPTION_MAX_AGE = 14,
  COAP_OPTION_URI_QUERY = 15,
  COAP_OPTION_ACCEPT = 17,
  COAP_OPTION_LOCATION_QUERY = 20,
  COAP_OPTION_BLOCK2 = 23,
  COAP_OPTION_BLOCK1 = 27,
  COAP_OPTION_SIZE2 = 28,
  COAP_OPTION_PROXY_URI = 35,
  COAP_OPTION_PROXY_SCHEME = 39,
  COAP_OPTION_SIZE1 = 60,
} coap_option_t;

