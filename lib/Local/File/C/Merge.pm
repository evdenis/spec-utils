package Local::File::C::Merge;

use strict;
use warnings;

use re '/aa';

use Graph::Directed;
use Exporter qw(import);
use Carp;
use Local::File::Merge qw(find_all merge);
use Local::List::Utils qw(intersection difference);
use File::Slurp qw(read_file);


our @EXPORT_OK = qw(find_headers find_sources find_all_files merge_headers merge_sources merge_all_files);


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

   my $hg = Graph::Directed->new();
   my @headers = find_headers($dir);

   my @headers_rel = map { substr($_, length $dir) } @headers; 
   my %h;

   foreach (@headers) {
      my $v = substr($_, length $dir);

      $hg->add_vertex($v);

      $h{$v} = [read_file $_];
      my @includes = map {m/[<"]([^">]++)[">]/; $1} grep {m/^\s*+\#\s*+include\s*+[<"][^">]++[">]/} @{ $h{$v} };
      # Может быть использовать вместо совпадение по регулярке /\Q$v\E$/ (конец файла)
      my @local_includes = intersection(\@headers_rel, \@includes);

      $hg->add_edges(map { ($_, $v) } @local_includes);
      
      #other includes
      if (defined $unmerged) {
         push @$unmerged, difference(\@includes, \@local_includes);
      }
   }

   my @order;
   while ($hg->vertices) {
      my @zv;
      foreach($hg->vertices) {
         push @zv, $_ if !$hg->in_degree($_);
      }

      croak("Cycle in include graph. Can't handle in current version.") if !@zv;

      $hg->delete_vertices( @zv );
      push @order, @zv;
   }

   my $h_code;
   foreach (@order) {
      $h_code .= join('', @{ $h{$_} })
   }

   $h_code
}

sub merge_sources ($)
{
   merge(find_sources($_[0]))
}

sub merge_all_files ($)
{
   merge_headers($_[0]) . merge_sources($_[0])
}

1;
