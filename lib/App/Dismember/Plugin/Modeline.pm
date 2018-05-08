package App::Dismember::Plugin::Modeline;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Basename;
use Cwd qw(abs_path);

=encoding utf8

=pod

=head1 Plugin::Modeline

Plugin::Modeline - плагин для добавления строки modeline в файлы

=head1 OPTIONS

=over 8

=item B<--plugin-modeline-string string>

Строка modeline. Добавляется в конец файлов.

=item B<--plugin-modeline-help>

Выводит полное описание плагина.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my $modeline;
   my $help = 0;

   GetOptions(
      'plugin-modeline-string=s' => \$modeline,
      'plugin-modeline-help'     => \$help,
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
         -msg     => "Option --plugin-modeline-string should be provided.\n",
         -exitval => 1
      }
   ) unless $modeline;

   chomp $modeline;

   $config->{'modeline'} = $modeline;

   bless {modeline => $modeline, single => $config->{single}}, $self;
}

sub level
{
   pre_output => 99;
}

sub action
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{output};

   print "plugin: modeline: adding modeline to files\n";
   unless ($self->{single}) {
      foreach (keys %{$opts->{output}}) {
         $opts->{output}{$_} = $opts->{output}{$_} . "\n\n/* $self->{modeline} */";
      }
   } else {
      $opts->{output}{module_c} = $opts->{output}{module_c} . "\n\n/* $self->{modeline} */";
   }

   undef;
}

1;
