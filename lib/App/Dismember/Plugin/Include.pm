package App::Dismember::Plugin::Include;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

sub process_options
{
   my ($self, $config) = @_;

   bless {}, $self
}

sub priority
{
   0
}

sub level
{
   # OUTPUT
   'pre_output'
}

sub action
{
   my ($self, $opts) = @_;

   undef
}


1;
