package Local::GCC::Preprocess;

use Exporter qw(import); 
use IPC::Open2;
use Carp;

use strict;
use warnings;


our @EXPORT_OK = qw(
      get_macro
      preprocess
      preprocess_directives_only
      preprocess_as_kernel_module
      preprocess_as_kernel_module_get_macro
);

sub call_gcc
{
   my $gcc_args = shift;
   my $code = shift;
   my $type = wantarray();
   my @res;
   my $res;


   my $pid = open2(\*GCC_OUT, \*GCC_IN, "gcc $gcc_args -");
   print GCC_IN $code;
   close GCC_IN;

   if ($type) {
      chomp(@res = <GCC_OUT>);
   } else {
      $res .= $_ while <GCC_OUT>;
   }

   close GCC_OUT;
   waitpid($pid, 0);

   return $type ? @res : $res;
}

sub get_macro ($)
{
   call_gcc('-dM -E -P', $_[0]);
}

sub preprocess ($)
{
   call_gcc('-E -P', $_[0]);
}

sub preprocess_directives_only
{
   call_gcc('-E -P -CC -fdirectives-only -nostdinc ', $_[0])
}


my @kernel_include_path = qw(
arch/x86/include/
arch/x86/include/generated/
include/
include/generated/
arch/x86/include/uapi/
arch/x86/include/generated/uapi/
include/uapi/
include/generated/uapi/
);

my $last_path = '';
my $gcc_include_path = undef;
my $stdlib = undef;

sub form_gcc_kernel_include_path
{
   my $kdir_path = shift;

   if ($last_path eq $kdir_path && defined $gcc_include_path) {
      return $gcc_include_path
   }

   croak("$kdir_path is not a kernel directory.") if ! -e "$kdir_path/Kbuild";

   $last_path = $kdir_path;
   $gcc_include_path = '';

   foreach (@kernel_include_path) {
      $gcc_include_path .= "-I ${kdir_path}/${_} "
   }

   if (!defined $stdlib) {
      my @str = split "\n",  `gcc -print-search-dirs`;
      $stdlib = substr($str[0], index($str[0], ': ') + 2) . 'include/';
   }

   $gcc_include_path .= "-I $stdlib";

   $gcc_include_path
}

sub add_directives
{
   $_[0] =
"#include <linux/kconfig.h>
#define MODULE 1
#define __KERNEL__ 1\n\n" . $_[0];

   $_[0]
}


sub preprocess_as_kernel_module
{
   call_gcc('-E -P -nostdinc ' . form_gcc_kernel_include_path($_[0]), add_directives($_[1]))
}

sub preprocess_as_kernel_module_get_macro
{
   call_gcc('-dM -E -P -nostdinc ' . form_gcc_kernel_include_path($_[0]), add_directives($_[1]))
}


1;
