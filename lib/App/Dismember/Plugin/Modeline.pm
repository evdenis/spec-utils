package App::Dismember::Plugin::Modeline;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Basename;
use Cwd qw(abs_path);

sub process_options
{
   my ($self, $config) = @_;
   my $modeline;

   GetOptions(
      'plugin-modeline-string=s' => \$modeline,
   ) or die("Error in command line arguments\n");

   die "Option --plugin-modeline-string should be provided.\n"
      unless $modeline;

   chomp $modeline;

   $config->{'modeline'} = $modeline;

   bless { modeline => $modeline, single => $config->{single} }, $self
}

sub level
{
   pre_output => 99
}

sub action
{
   my ($self, $opts) = @_;

   return undef
      unless exists $opts->{output};

   print "plugin: modeline: adding modeline to files\n";
   unless ($self->{single}) {
      foreach (keys %{$opts->{output}}) {
         $opts->{output}{$_} = $opts->{output}{$_} .
                                 "\n\n/* $self->{modeline} */";
      }
   } else {
         $opts->{output}{module_c} = $opts->{output}{module_c} .
                                     "\n\n/* $self->{modeline} */";
   }

   undef
}


1;
