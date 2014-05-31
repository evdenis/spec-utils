package Local::File::C::Merge;

use strict;
use warnings;

use re '/aa';

use Exporter qw(import);
use Graph::Directed;
use Carp;
use File::Slurp qw(read_file);
use Cwd qw(realpath);
use File::Spec::Functions qw(catfile splitpath);

use Local::File::Merge qw(find_all merge);
use Local::List::Utils qw(intersection difference);


our @EXPORT_OK = qw(find_headers find_sources find_all_files merge_headers merge_sources merge_all_files_simple merge_all_files);


sub find_headers ($)
{
   find_all($_[0], qr/\.h$/)
}

sub find_sources ($)
{
   find_all($_[0], qr/\.c$/)
}

sub find_all_files ($)
{
   find_all($_[0], qr/\.[ch]$/)
}

sub merge_headers ($;$)
{
   my ($dir, $unmerged) = @_;

   my %h;
   foreach my $file (find_headers($dir)) {
      $h{$file}{name} = substr($file, length $dir);
      $h{$file}{cwd}  = (splitpath($h{$file}{name}))[1];
      $h{$file}{file} = read_file($file, scalar_ref => 1);
   }

   my $hg = Graph::Directed->new();
   while (my ($path, $attrs) = each %h) {
      $hg->add_vertex($path);

      while (${ $attrs->{file} } =~ /^\h*+#\h*+include\h*+[<"]([^">]++)[">]/gm) {
         my $include = $1;
         my $file = do {
            if ($attrs->{cwd}) {
               my $f = realpath(catfile($dir, $attrs->{cwd}, $include));
               $f = realpath(catfile($dir, $include)) unless $f && exists $h{$f};
               $f
            } else {
               realpath(catfile($dir, $include))
            }
         };

         #don't test for existatnce, since it is already reded by read_file
         if ($file && exists $h{$file}) {
            $hg->add_edge($file, $path)
         } elsif (defined $unmerged) {
            push @$unmerged, $include;
         }
      }
   }

   my @order;
   while ($hg->vertices) {
      my @zv;
      foreach($hg->vertices) {
         push @zv, $_
            unless $hg->in_degree($_);
      }

      croak("Cycle in include graph. Can't handle in current version.")
         unless @zv;

      $hg->delete_vertices( @zv );
      push @order, @zv;
   }

   my $h_code;
   foreach (@order) {
      $h_code .= ${ $h{$_}{file} }
   }

   $h_code
}

sub merge_sources ($)
{
   merge(find_sources($_[0]))
}

sub merge_all_files_simple ($)
{
   merge(find_all_files($_[0]))
}

sub merge_all_files ($)
{
   merge_headers($_[0]) . merge_sources($_[0])
}

1;
