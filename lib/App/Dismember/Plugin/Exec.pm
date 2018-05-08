package App::Dismember::Plugin::Exec;

use Pod::Usage;
use Pod::Find qw(pod_where);
use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::Exec

Plugin::Exec - плагин для запуска программы после вывода результатов работы dismember для конкретной функции

=head1 OPTIONS

=over 8

=item B<--plugin-exec-file path>

Путь до исполняемого файла. В качестве аргументов командной строки передаются все зарегестрированные опции предыдущих плагинов и опция --dir path, где path - это путь до директории с файлами.

=item B<--[no-]plugin-exec-wait>

Ожидать или не ожидать конца исполнения вызываемой программы. По умолчанию плагин ожидает конца выполнения запускаемой программы.

=item B<--plugin-exec-help>

Выводит полное описание плагина.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my $file;
   my $help = 0;
   my $wait = 1;

   GetOptions(
      'plugin-exec-file=s' => \$file,
      'plugin-exec-wait!'  => \$wait,
      'plugin-exec-help'   => \$help,
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
         -msg     => "Option --plugin-exec-file should be provided.\n",
         -exitval => 1
      }
   ) unless $file;

   unless (-f $file && -r _ && -x _) {
      die "FAIL: Can't access file $file.\n";
   }

   $config->{'exec-file'} = $file;

   bless {file => $file, wait => $wait}, $self;
}

sub level
{
   post_output => 99;
}

sub action
{
   my ($self, $opts) = @_;

   return undef
     if !(exists $opts->{'dir'}) || !(exists $opts->{'file'});

   my $pid = fork();
   die "FAIL: can't fork $!"
     unless defined $pid;

   unless ($pid) {
      my %args;
      foreach (keys %$opts) {
         unless (ref $opts->{$_}) {
            $args{'--' . $_} = $opts->{$_};
         }
      }
      my $cfile = (grep {m/\.c$/} @{$opts->{'file'}})[0];
      $args{'--file'} = $cfile;
      print "EXEC: $self->{file} @{[%args]}\n";

      open(STDIN, '</dev/null');
      unless ($self->{wait}) {
         open(STDOUT, '>/dev/null');
         open(STDERR, '>&STDOUT');
      }
      exec($self->{file}, %args);
   }

   if ($self->{wait}) {
      waitpid $pid, 0;
      if ($?) {
         die "EXEC: $self->{file} failed with code $?\n";
      }
   }

   undef;
}

1;
