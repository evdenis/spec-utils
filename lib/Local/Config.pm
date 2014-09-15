package Local::Config;

use warnings;
use strict;

use Exporter qw(import);
use FindBin;
use File::Basename;
use File::Spec::Functions qw(catfile);

our @EXPORT_OK = qw(find_config);

sub find_config
{
   my $r = undef;
   my $pname = basename $0;
   my @paths = (
      catfile($FindBin::Bin, ".${pname}.conf"),
      catfile($ENV{HOME}, '.config', $pname, 'config')
   );

   foreach (@paths) {
      if (-r $_) {
         $r = $_;
         last
      }
   }

   $r
}

1;
