#!/usr/bin/perl

use warnings;
use strict;

use Test::More tests => 22;
use Test::Deep;

use C::GlobalSet;

my $set = C::GlobalSet->parse(\join('', <DATA>), 'kernel');

my %g;
$g{$_->name} = $_ foreach @{$set->set};

cmp_deeply([sort keys %g], [qw(cpu_stop current_task fs_type read_f socket_update_slock unix_socket_table)], 'globals');

is($g{unix_socket_table}->type,   'struct hlist_head ',       'type test 1');
is($g{fs_type}->type,             'struct file_system_type ', 'type test 2');
is($g{socket_update_slock}->type, 'spinlock_t',               'type test 3');
is($g{current_task}->type,        'struct task_struct *',     'type test 4');
is($g{read_f}->type, 'int (*read_f[SYM_NUM]) (struct policydb *p, struct hashtab *h, void *fp)', 'type test 5');

ok($g{unix_socket_table}->extern, 'extern test true 1');
ok($g{current_task}->extern,      'extern test true 2');
ok(!$g{fs_type}->extern,          'extern test false');

is($g{unix_socket_table}->modifier, 'extern ', 'modifier test 1');
is($g{fs_type}->modifier,           undef,     'modifier test 2');
is($g{read_f}->modifier,            'static ', 'modifier test 3');

ok(!$g{unix_socket_table}->initialized, 'initialized test 1');
ok($g{fs_type}->initialized,            'initialized test 2');
ok($g{read_f}->initialized,             'initialized test 3');
ok($g{cpu_stop}->initialized,           'initialized test 4');

is($g{unix_socket_table}->initializer, undef, 'initializer test 1');
is(
   $g{fs_type}->initializer, '{
   .name    = FS_NAME,
   .mount   = mnt,
   .kill_sb = kill_litter_super,
}', 'initializer test 2'
);
is(
   $g{read_f}->initializer, '{
   common_read,
   class_read,
   role_read,
   type_read,
   user_read,
   cond_read_bool,
   sens_read,
   cat_read,
}', 'initializer test 3'
);
is($g{cpu_stop}->initializer, '0', 'initializer test 4');

cmp_deeply($set->ids,
   bag(["unix_socket_table"], ["fs_type"], ["socket_update_slock"], ["current_task"], ["cpu_stop"], ["read_f"]), 'ids');

cmp_deeply(
   $set->tags,
   bag(
      [["struct", "hlist_head"], "UNIX_HASH_SIZE"],
      [["struct", "file_system_type"], "name", "FS_NAME", "mount", "mnt", "kill_sb", "kill_litter_super"],
      ["DEFINE_SPINLOCK"],
      [["struct", "task_struct"]],
      [],
      [
         "SYM_NUM", ["struct", "policydb"], "p", ["struct", "hashtab"],
         "h",         "fp",        "common_read", "class_read",
         "role_read", "type_read", "user_read",   "cond_read_bool",
         "sens_read", "cat_read"
      ]
   ),
   'tags'
);

__DATA__

extern struct hlist_head unix_socket_table[2 * UNIX_HASH_SIZE];

struct file_system_type fs_type =
{
   .name    = FS_NAME,
   .mount   = mnt,
   .kill_sb = kill_litter_super,
};

static DEFINE_SPINLOCK(socket_update_slock);

extern  __typeof__(struct task_struct *) current_task;

__typeof__(unsigned long) cpu_stop = 0;

static int (*read_f[SYM_NUM]) (struct policydb *p, struct hashtab *h, void *fp) =
{
   common_read,
   class_read,
   role_read,
   type_read,
   user_read,
   cond_read_bool,
   sens_read,
   cat_read,
};


