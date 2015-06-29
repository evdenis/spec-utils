package App::Dismember::Plugin::Rewrite;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

sub process_options
{
   my ($self, $config) = @_;
   my @rewrite;
   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;

   GetOptions(
      'plugin-rewrite-id=s'     => \@rewrite,
      'plugin-rewrite-reduced!' => \$reduced
   ) or die("Error in command line arguments\n");

   die "Option --plugin-rewrite-id should be provided.\n"
      unless @rewrite;

   my %rewrite;
   foreach (@rewrite) {
      chomp;
      if (m/\A([a-zA-Z_]\w+)\^(.*)\Z/) {
         $rewrite{$1} = $2
      } else {
         die "Can't parse rewrite id '$_'\n"
      }
   }

   $config->{'rewrite'} = \%rewrite;

   bless { rewrite => \%rewrite, reduced => $reduced }, $self
}

sub priority
{
   10
}

sub level
{
   $_[0]->{reduced} ? 'reduced_graph' : 'full_graph'
}

sub action
{
   my ($self, $opts) = @_;

   return undef
      unless exists $opts->{'graph'};

   my $g = $opts->{'graph'};

NEXT:   foreach my $id (keys %{$self->{rewrite}}) {
      print "plugin: rewrite: rewriting $id\n";

      foreach($g->vertices) {
         if ($g->get_vertex_attribute($_, 'object')->name eq $id) {
            $g->get_vertex_attribute($_, 'object')->code($self->{rewrite}{$id});
            next NEXT;
         }
      }

      warn "plugin: rewrite: vertex $id doesn't exist in graph\n"
   }

   undef
}


1;
