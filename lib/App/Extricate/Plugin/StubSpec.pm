package App::Extricate::Plugin::StubSpec;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Scalar::Util qw(blessed);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::StubSpec

Plugin::StubSpec - add stub ACSL specification to declarations and definitions
of functions

=head1 OPTIONS

=over 8

=item B<--[no-]plugin-stubspec-reduced>

Defines the plugin level of operating. The plugin will run either on a full
graph of sources or a reduced one for a particular function. The plugin
works with a full graph by default then there is more than one function
in the --functions argument, on a reduced graph otherwise. The option affects
performance only.

=item B<--plugin-stubspec-help>

Display this information.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my $help    = 0;
   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;

   GetOptions(
      'plugin-stubspec-reduced!' => \$reduced,
      'plugin-stubspec-help'     => \$help,
   ) or die("Error in command line arguments\n");

   pod2usage(
      {
         -input   => pod_where({-inc => 1}, __PACKAGE__),
         -verbose => 2,
         -exitval => 0
      }
   ) if $help;

   bless {reduced => $reduced}, $self;
}

sub level
{
   (($_[0]->{reduced} ? 'reduced_graph' : 'full_graph'), 99);
}

my %processed_objects;

sub action
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{'graph'};

   my $g = $opts->{'graph'};

   print "plugin: stub_spec: adding meaningless specifications\n";

   foreach ($g->vertices) {
      my $o    = $g->get_vertex_attribute($_, 'object');
      my $area = $o->area;
      my $type = blessed($o);

      if ($area eq 'kernel') {
         unless ($type eq 'C::Declaration') {
            next;
         }
      } else {
         if ($type eq 'C::Acslcomment') {
            $g->delete_vertex($_);
         }
         unless ($type eq 'C::Function') {
            next;
         }
      }

      # check already processed
      unless (exists $processed_objects{$_}) {
         $o->clean_comments();
         $o->add_spec('terminates \true;');
         $processed_objects{$_} = undef;
      }
   }

   undef;
}

1;
