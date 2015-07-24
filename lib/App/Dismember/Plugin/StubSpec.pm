package App::Dismember::Plugin::StubSpec;

use warnings;
use strict;

use Scalar::Util qw(blessed);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

sub process_options
{
   my ($self, $config) = @_;

   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;

   GetOptions(
      'plugin-stubspec-reduced!' => \$reduced
   ) or die("Error in command line arguments\n");

   bless { reduced => $reduced }, $self
}

sub level
{
   $_[0]->{reduced} ? 'reduced_graph' : 'full_graph', 99
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
      my $o = $g->get_vertex_attribute($_, 'object');
      my $area = $o->area;
      my $type = blessed($o);

      if ($area eq 'kernel') {
         unless ($type eq 'C::Declaration') {
            next
         }
      } else {
         unless ($type eq 'C::Function') {
            next
         }
      }

      # check already processed
      unless (exists $processed_objects{$_}) {
         $o->clean_comments();
         $o->add_spec('terminates \true;');
         $processed_objects{$_} = undef;
      }
   }

   undef
}


1;
