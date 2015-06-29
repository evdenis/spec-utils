package App::Dismember::Plugin::Filter;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

sub process_options
{
   my ($self, $config) = @_;
   my @filter;
   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;

   GetOptions(
      'plugin-filter-name=s'   => \@filter,
      'plugin-filter-reduced!' => \$reduced
   ) or die("Error in command line arguments\n");

   die "Option --plugin-filter-name should be provided.\n"
      unless @filter;

   $config->{'filter'} = \@filter;

   bless { filter => \@filter, reduced => $reduced }, $self
}

sub priority
{
   0
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

FILTER:   foreach my $name (@{$self->{filter}}) {
      print "plugin: filter: removing $name from graph\n";

      foreach($g->vertices) {
         if ($g->get_vertex_attribute($_, 'object')->name eq $name) {
            $g->delete_vertex($_); # delete only one vertex! Dependants will be filtered out later.
            next FILTER;
         }
      }

      warn "plugin: filter: vertex $name doesn't exist in graph\n"
   }

   undef
}


1;
