package App::Extricate::Plugin::Rewrite;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use RE::Common qw($varname);

=encoding utf8

=pod

=head1 Plugin::Rewrite

Plugin::Rewrite - rewrite definitions of structures, functions, macro, etc

=head1 OPTIONS

=over 8

=item B<--plugin-rewrite-id string>

Overwrite definition of an entity from the argument "string". The argument should
be of the format 'name^new_definition'.

=item B<--plugin-rewrite-name string>

Rewrite definition of an entity from the argument "string". The argument should
be of the format 'name^new_definition'. Main difference with C<--plugin-rewrite-id>
is that all deps are detached from the node.

=item B<--[no-]plugin-rewrite-reduced>

Defines the plugin level of operating. The plugin will run either on a full
graph of sources or on a reduced one for a particular function. The plugin
works with a full graph by default when there is more than one function in
the --functions argument, on a reduced graph otherwise. The option affects
performance only.

=item B<--plugin-rewrite-help>

Display this information.

=back

=cut

sub parse_rewrite_arg
{
   my $rewrite = {};

   foreach (@_) {
      chomp;
      if (m/\A($varname)\^(.*)\Z/) {
         $rewrite->{$1} = $2;
      } else {
         die "Can't parse rewrite id '$_'\n";
      }
   }

   return $rewrite;
}

sub process_options
{
   my ($self, $config) = @_;
   my @overwrite;
   my @rewrite;
   my $help    = 0;
   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;

   GetOptions(
      'plugin-rewrite-id=s'     => \@overwrite,
      'plugin-rewrite-name=s'   => \@rewrite,
      'plugin-rewrite-reduced!' => \$reduced,
      'plugin-rewrite-help'     => \$help,
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
         -msg     => "Option --plugin-rewrite-{id,name} should be provided.\n",
         -exitval => 1
      }
   ) if !@overwrite && !@rewrite;

   my %overwrite;

   $config->{'overwrite'} = parse_rewrite_arg @overwrite;
   $config->{'rewrite'}   = parse_rewrite_arg @rewrite;

   bless {
      overwrite => $config->{'overwrite'},
      rewrite   => $config->{'rewrite'},
      reduced   => $reduced
   }, $self;
}

sub level
{
   (($_[0]->{reduced} ? 'reduced_graph' : 'full_graph'), 10);
}

sub action
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{'graph'};

   my %overwrite = %{$self->{overwrite}};
   my %rewrite   = %{$self->{rewrite}};
   my %list      = map {$_ => 1} (keys %overwrite, keys %rewrite);

   my $g = $opts->{'graph'};

   foreach my $id ($g->vertices) {
      my $o    = $g->get_vertex_attribute($id, 'object');
      my $name = $o->name;

      if ($overwrite{$name}) {
         print "plugin: rewrite: overwriting $name\n";
         $o->code($overwrite{$name});
         delete $list{$name};
      }

      if ($rewrite{$name}) {
         print "plugin: rewrite: rewriting $name\n";
         $o->code($rewrite{$name});
         $g->delete_edges(map {@{$_}} $g->edges_to($id));
         delete $list{$name};
      }
   }
   foreach (keys %list) {
      warn "plugin: rewrite: vertex $_ doesn't exist in graph\n";
   }

   undef;
}

1;
