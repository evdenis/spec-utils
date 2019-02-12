package App::Extricate::Plugin::TestCompile;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Test::More;
use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::TestCompile

Plugin::TestCompile - плагин для теста компиляции сгенерированного исходного кода

=head1 OPTIONS

=over 8

=item B<--plugin-testcompile-help>

Выводит полное описание плагина.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my $help = 0;

   GetOptions('plugin-testcompile-help' => \$help,)
     or die("Error in command line arguments\n");

   my $input = pod_where({-inc => 1}, __PACKAGE__);
   pod2usage(
      {
         -input   => $input,
         -verbose => 2,
         -exitval => 0
      }
   ) if $help;

   bless {}, $self;
}

sub level
{
   return (
      post_output => 90,
      before_exit => 99
   );
}

sub action
{
   my ($self, $opts) = @_;

   if ($opts->{level} eq 'post_output') {
      goto &action_test;
   } elsif ($opts->{level} eq 'before_exit') {
      goto &action_done_testing;
   } else {
      die "plugin: testcompile: should not be called from level $opts->{level}\n";
   }
}

sub action_done_testing
{
   my ($self, $opts) = @_;

   done_testing();
}

sub action_test
{
   my ($self, $opts) = @_;

   return undef
     if !(exists $opts->{'dir'}) || !(exists $opts->{'file'});

   my $pid = fork();
   die "FAIL: can't fork $!"
     unless defined $pid;

   my $cfile = (grep {m/\.c$/} @{$opts->{'file'}})[0];
   unless ($pid) {
      open(STDIN, '</dev/null');
      exec("gcc -c -w -o /dev/null $cfile");
   }

   waitpid $pid, 0;
   ok(!$?, "Compilation $cfile");

   undef;
}

1;
