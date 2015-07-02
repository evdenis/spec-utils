package App::Dismember::Plugin::Include;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Basename;
use File::Spec::Functions qw(catfile);
use File::Copy;

sub process_options
{
   my ($self, $config) = @_;
   my @include;

   GetOptions(
      'plugin-include-file=s' => \@include
   ) or die("Error in command line arguments\n");

   die "Option --plugin-include-file should be provided.\n"
      unless @include;

   my %include;
   foreach (@include) {
      chomp;
      if (m/\A([a-zA-Z_]\w+)\^(.*)\Z/) {
         my ($area, $path) = ($1, $2);
         unless (exists $Kernel::Module::Graph::out_file{$area}) {
            die "There is no such area $area\n"
         }
         unless (-r $path) {
            die "Can't read file $path\n"
         }
         push @{ $include{$area} }, $path
      } else {
         die "Can't parse include id '$_'\n"
      }
   }

   $config->{'include'} = \%include;

   bless { include => \%include, base_dir => $config->{output_dir} }, $self
}

sub priority
{
   99
}

sub level
{
   'pre_output'
}

sub action
{
   my ($self, $opts) = @_;

   return undef
      unless exists $opts->{output} && exists $opts->{output_dir};

   foreach my $area (keys %{$self->{include}}) {
      foreach (@{$self->{include}{$area}}) {
         my $include = basename $_;
         my $dst = catfile($opts->{output_dir}, $include);
         copy($_, $dst);
         print "plugin: include: copy $_ -> $dst\n";

         $opts->{'output'}{$area} = qq(#include "$include"\n\n) .
                                 $opts->{'output'}{$area};
      }
   }

   undef
}


1;
