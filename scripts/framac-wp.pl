#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;

my %args = @ARGV;
my $file = $args{'--file'};

die("$0: --file <file> is the required argument\n")
   unless $file;

die("Can't read file $file\n")
   unless -r $file;

my $func = $args{'--function'} // 'unknown';

my $output = qx(frama-c -wp -wp-rte -wp-model "Typed+Cast" -wp-prover alt-ergo,cvc4,z3 "$file" 2>&1);

die("Unable to launch external process: $!\n")
   if not defined $output;

print "VERDICT: $func ";

if ($?) {
   print "INSTRUMENT FAIL\n<--\n$output\n-->\n";
   die("Frama-C (error code $?)\n");
}

my $strategy_scheduled = 0;

$strategy_scheduled = 1
   if $output =~ m/(?<goals>\d++)\h++goals?\h++scheduled/;

if (!$strategy_scheduled || $+{goals} == 0) {
   print "NOSPEC\n";
} elsif ($output =~ m!Proved goals:\h*+(?<proved>\d+)\h*+/\h*+(?<total>\d+)!) {
   my $begin  = $-[0];
   my $proved = $+{proved};
   my $total  = $+{total};

   if ($proved == $total) {
      print "PROVED\n";
   } elsif ($proved <= $total) {
      my $report = substr($output, $begin);
      if ($proved == 0) {
         print "UNPROVED\n";
      } else {
         print "PARTIALLY PROVED ($proved / $total)\n";
      }
      print "<--\n$report\n-->\n";
   } else {
      die "Can't match output for function $func.\n Output: $output\n";
   }
} else {
   die "Can't match output for function $func.\n Output: $output\n";
}

