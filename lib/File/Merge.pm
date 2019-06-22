package File::Merge;

use strict;
use warnings;

use File::Find;
use File::Slurp qw(read_file);
use File::Spec::Functions qw(catfile);
use Cwd qw(realpath);
use Exporter qw(import);

use Configuration qw(recursive_search);

our @EXPORT_OK = qw(find_all merge merge_all);

sub find_all ($$;$)
{
   my $dirs = shift;
   my $mask = shift;
   my $rec  = shift;
   my @files;

   if (ref($dirs) ne 'ARRAY') {
      $dirs = [$dirs];
   }

   $rec = recursive_search()
     unless defined $rec;

   if ($rec) {
      finddepth(
         {
            wanted => sub {push @files, realpath($File::Find::name) if m/${mask}/}
         },
         map {
            realpath $_
         } @$dirs
      );
   } else {
      foreach my $path (@$dirs) {
         if (-d $path) {
            if (opendir my $dir, $path) {
               push @files, map {catfile($path, $_)} readdir $dir;
               closedir $dir;
            }
         } else {
            push @files, $path;
         }
         @files = map {$_ =~ m/${mask}/ && -f $_ ? realpath($_) : ()} @files;
      }
   }

   @files;
}

sub merge (@)
{
   my $code = '';
   $code .= read_file($_, err_mode => 'carp') foreach @_;

   $code;
}

sub merge_all ($$)
{
   merge find_all($_[0], $_[1]);
}

1;
