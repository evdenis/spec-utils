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

Plugin::Rewrite - плагин для переписывания определений структур, функций, макросов и т. д.

=head1 OPTIONS

=over 8

=item B<--plugin-rewrite-id string>

Переписать определение сущности из string. string имеет формат 'entity_name^new_entity_definition'

=item B<--[no-]plugin-rewrite-reduced>

Опция определяет уровень работы плагина. Для всего графа либо для урезанного графа конкретной функции. По умолчанию, когда extricate запускается с несколькими функциями в опции --functions, плагин работает на уровне всего графа, в обратном случае на уровне урезанного графа конкретной функции. Опция влияет на быстродействие.

=item B<--plugin-rewrite-help>

Выводит полное описание плагина.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my @rewrite;
   my $help = 0;
   my $reduced = @{$config->{functions}} > 1 || $config->{all} ? 0 : 1;

   GetOptions(
      'plugin-rewrite-id=s'     => \@rewrite,
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
         -msg     => "Option --plugin-rewrite-id should be provided.\n",
         -exitval => 1
      }
   ) unless @rewrite;

   my %rewrite;
   foreach (@rewrite) {
      chomp;
      if (m/\A$varname\^(.*)\Z/) {
         $rewrite{$1} = $2;
      } else {
         die "Can't parse rewrite id '$_'\n";
      }
   }

   $config->{'rewrite'} = \%rewrite;

   bless {rewrite => \%rewrite, reduced => $reduced}, $self;
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

   my $g = $opts->{'graph'};

 NEXT: foreach my $id (keys %{$self->{rewrite}}) {
      print "plugin: rewrite: rewriting $id\n";

      foreach ($g->vertices) {
         if ($g->get_vertex_attribute($_, 'object')->name eq $id) {
            $g->get_vertex_attribute($_, 'object')->code($self->{rewrite}{$id});
            next NEXT;
         }
      }

      warn "plugin: rewrite: vertex $id doesn't exist in graph\n";
   }

   undef;
}

1;
