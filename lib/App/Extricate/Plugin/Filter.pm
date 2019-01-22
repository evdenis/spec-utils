package App::Extricate::Plugin::Filter;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::Filter

Plugin::Filter - плагин для исключения из вывода структур, функций, макросов и т. д.

=head1 OPTIONS

=over 8

=item B<--plugin-filter-name name>

Исключить из вывода сущность name.

=item B<--[no-]plugin-filter-reduced>

Опция определяет уровень работы плагина. Для всего графа либо для урезанного графа конкретной функции. По умолчанию, когда extricate запускается с несколькими функциями в опции --functions, плагин работает на уровне всего графа, в обратном случае на уровне урезанного графа конкретной функции. Опция влияет на быстродействие.

=item B<--plugin-filter-help>

Выводит полное описание плагина.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my @filter;
   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;
   my $help = 0;

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
   $_[0]->{reduced} ? 'reduced_graph' : 'full_graph', 0;
}

sub action
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{'graph'};

   my $g = $opts->{'graph'};

 FILTER: foreach my $name (@{$self->{filter}}) {
      print "plugin: filter: removing $name from graph\n";

      foreach ($g->vertices) {
         if ($g->get_vertex_attribute($_, 'object')->name eq $name) {
            $g->delete_vertex($_);    # delete only one vertex! Dependants will be filtered out later.
            next FILTER;
         }
      }

      warn "plugin: filter: vertex $name doesn't exist in graph\n";
   }

   undef;
}

1;
