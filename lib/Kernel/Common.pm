package Kernel::Common;

use strict;
use warnings;

use feature qw(state);
use Local::List::Util qw(any);
use File::Spec::Functions qw(catfile);
use Exporter qw(import);
use Configuration::Linux qw(get_files_to_check_repo);

our @EXPORT_OK = qw(check_kernel_dir check_kernel_files_readable autodetect_kernel_directory);

sub check_kernel_dir ($)
{
   my $res = 0;
   state %kerneldir_cache;

   return 0 unless $_[0];
   return $kerneldir_cache{$_[0]}
     if exists $kerneldir_cache{$_[0]};

   if (-d $_[0]) {
      opendir my $kdir, $_[0] or goto OUT;
      my @files = readdir $kdir;
      closedir $kdir;

      # Check for standard files
      foreach (get_files_to_check_repo()) {
         goto OUT
           unless any($_, \@files);
      }

      $res = 1;
   }

 OUT:
   $kerneldir_cache{$_[0]} = $res;
   $res;
}

sub check_kernel_files_readable ($@)
{
   my ($dir, @files) = @_;

   if (check_kernel_dir($_[0])) {
      foreach (@files) {
         return 0
           unless -r catfile($dir, $_);
      }

      return 1;
   }

   0;
}

sub autodetect_kernel_directory
{
   foreach (@{$_{dirs}}, '.', $ENV{CURRENT_KERNEL}, 'linux', 'linux-stable', 'kernel', 'kernel-stable') {
      return $_
        if check_kernel_files_readable($_, @{$_{files}});
   }

   undef;
}

1;
