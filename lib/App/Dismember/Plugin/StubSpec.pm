package App::Dismember::Plugin::StubSpec;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Scalar::Util qw(blessed);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::StubSpec

Plugin::StubSpec - плагин для добавления спецификаций-заглушек к декларациям функций и функциям

=head1 OPTIONS

=over 8

=item B<--[no-]plugin-stubspec-reduced>

Опция определяет уровень работы плагина. Для всего графа либо для урезанного графа конкретной функции. По умолчанию, когда dismember запускается с несколькими функциями в опции --functions, плагин работает на уровне всего графа, в обратном случае на уровне урезанного графа конкретной функции. Опция влияет на быстродействие.

=item B<--plugin-stubspec-help>

Выводит полное описание плагина.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my $help = 0;
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
   $_[0]->{reduced} ? 'reduced_graph' : 'full_graph', 99;
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
