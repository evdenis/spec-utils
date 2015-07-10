package App::Dismember::Plugin::Exec;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

sub process_options
{
   my ($self, $config) = @_;
   my $file;
   my $wait = 1;

   GetOptions(
      'plugin-exec-file=s' => \$file,
      'plugin-exec-wait!'  => \$wait,
   ) or die("Error in command line arguments\n");

   die "Option --plugin-exec-file should be provided.\n"
      unless $file;

   unless (-f $file && -r _ && -x _) {
      die "FAIL: Can't access file $file.\n"
   }

   $config->{'exec-file'} = $file;

   bless { file => $file, wait => $wait }, $self
}

sub level
{
   post_output => 99
}

sub action
{
   my ($self, $opts) = @_;

   return undef
      unless exists $opts->{'dir'};

   my $pid = fork();
   die "FAIL: can't fork $!"
      unless defined $pid;

   unless ($pid) {
      my %args;
      foreach (keys %$opts) {
         unless (ref $opts->{$_}) {
            $args{'--' . $_} = $opts->{$_}
         }
      }
      print "EXEC: $self->{file} @{[%args]}\n";

      open (STDIN,  '</dev/null');
      unless ($self->{wait}) {
         open (STDOUT, '>/dev/null');
         open (STDERR, '>&STDOUT');
      }
      exec($self->{file}, %args);
   }

   if ($self->{wait}) {
      waitpid $pid, 0;
      if ($?) {
         die "EXEC: $self->{file} failed with code $?\n"
      }
   }

   undef
}


1;
