package File::Merge;

use strict;
use warnings;

use File::Find;
use File::Slurp qw(read_file);
use Cwd qw(realpath);
use Exporter qw(import);

our @EXPORT_OK = qw(find_all merge merge_all);


sub find_all ($$)
{
   my $dir = shift;
   my $mask = shift;
   my @files;

   find({ wanted => sub { push @files, realpath($File::Find::name) if m/${mask}/ } }, realpath($dir));

   @files
}

sub merge (@)
{
   my $code;
   $code .= read_file($_, err_mode => 'carp') foreach @_;

   $code
}

sub merge_all ($$)
{
   merge find_all($_[0], $_[1])
}

1;
