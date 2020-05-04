package App::Extricate::Plugin::Filter;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::Filter

Plugin::Filter - filter out structures, functions, macro, etc from output

=head1 OPTIONS

=over 8

=item B<--plugin-filter-name name>

Filter out the definition "name" from output.

=item B<--[no-]plugin-filter-reduced>

Defines the plugin level of operating. The plugin will run either on a full
graph of sources or on a reduced one for a particular function. The plugin
works with a full graph by default when there is more than one function in
the --functions argument, on a reduced graph otherwise. The option affects
performance only.

=item B<--plugin-filter-help>

Display this information.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my @filter;
   my $reduced = (@{$config->{functions}} > 1 || $config->{all}) ? 0 : 1;
   my $help    = 0;

   GetOptions(
      'plugin-filter-name=s'   => \@filter,
      'plugin-filter-reduced!' => \$reduced,
      'plugin-filter-help'     => \$help,
   ) or die("Error in command line arguments\n");

   my $input = pod_where({-inc => 1}, __PACKAGE__);
   pod2usage(
      {
         -input   => $input,
         -verbose => 2,
         -exitval => 0
      }
   ) if $help;

   pod2usage(
      {
         -input   => $input,
         -msg     => "Option --plugin-filter-name should be provided.\n",
         -exitval => 1
      }
   ) unless @filter;

   $config->{'filter'} = \@filter;

   bless {filter => \@filter, reduced => $reduced}, $self;
}

sub level
{
   (($_[0]->{reduced} ? 'reduced_graph' : 'full_graph'), 0);
}

sub action
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{'graph'};

   my $g = $opts->{'graph'};

   foreach my $name (@{$self->{filter}}) {
      print "plugin: filter: removing $name from graph\n";
      foreach ($g->vertices) {
         if ($g->get_vertex_attribute($_, 'object')->name eq $name) {
            $g->delete_vertex($_);    # delete only one vertex! Dependants will be filtered out later.
         }
      }
   }

   undef;
}

1;
