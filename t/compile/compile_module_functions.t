#!/usr/bin/env perl

use warnings;
use strict;

use Test::More;
use lib::abs;

my $kernel    = $ENV{KERNEL} // lib::abs::path('../../linux-4.16.8');
my $module    = $kernel . '/fs/ramfs';
my $dismember = lib::abs::path("../../bin/dismember");

qx($dismember --full --single --cache=0 --plugin=testcompile --all --kernel $kernel --module $module);

done_testing();
