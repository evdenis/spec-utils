package Local::Config;

use warnings;
use strict;
use utf8::all;

use Exporter qw(import);
use FindBin;
use File::Basename;
use File::Spec::Functions qw(catfile);
use YAML qw(LoadFile);
use Carp;

our @EXPORT_OK = qw(find_config load_config merge_config_keys update_config_keys);

sub find_config
{
   my $r     = undef;
   my $pname = $_[0] // basename $0;
   my @paths = (
      catfile($FindBin::Bin, ".${pname}.cfg"),
      catfile($FindBin::Bin, ".${pname}.conf"),
      catfile($FindBin::Bin, ".${pname}.config"),

      catfile($ENV{HOME}, '.config', "${pname}.cfg"),
      catfile($ENV{HOME}, '.config', "${pname}.conf"),
      catfile($ENV{HOME}, '.config', "${pname}.config"),

      catfile($ENV{HOME}, '.config', $pname, 'cfg'),
      catfile($ENV{HOME}, '.config', $pname, 'conf'),
      catfile($ENV{HOME}, '.config', $pname, 'config'),
   );

   foreach (@paths) {
      if (-r $_) {
         $r = $_;
         last;
      }
   }

   $r;
}

sub load_config
{
   if ($_[0] && -r $_[0]) {
      LoadFile($_[0]);
   } else {
      undef;
   }
}

sub merge_config_keys
{
   foreach (keys %{$_[1]}) {
      unless (exists $_[0]->{$_}) {
         $_[0]->{$_} = $_[1]->{$_};
      } else {
         croak "Duplicate key $_ in configurations\n";
      }
   }
   undef;
}

sub update_config_keys
{
   foreach (keys %{$_[1]}) {
      $_[0]->{$_} = $_[1]->{$_};
   }
   undef;
}

1;
