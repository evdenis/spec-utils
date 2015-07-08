package App::Dismember::Plugin::Inline;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Slurp qw(read_file);
use File::Basename;
use Cwd qw(abs_path);

sub process_options
{
   my ($self, $config) = @_;
   my @inline;

   GetOptions(
      'plugin-inline-file=s' => \@inline,
   ) or die("Error in command line arguments\n");

   die "Option --plugin-inline-file should be provided.\n"
      unless @inline;

   my %inline;
   foreach (@inline) {
      chomp;
      if (m/\A([a-zA-Z_]\w+)\^(.*)\Z/) {
         my ($area, $path) = ($1, $2);
         unless (exists $Kernel::Module::Graph::out_file{$area}) {
            die "There is no such area $area\n"
         }
         unless (-r $path) {
            die "Can't read file $path\n"
         }
         push @{ $inline{$area} }, $path
      } else {
         die "Can't parse inline id '$_'\n"
      }
   }

   $config->{'inline'} = \%inline;

   bless { inline => \%inline }, $self
}

sub priority
{
   80
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

   foreach my $area (keys %{$self->{inline}}) {
      foreach (@{$self->{inline}{$area}}) {
         my $name = basename $_;
         $opts->{'output'}{$area} = "\n//INLINE $name BEGIN\n\n" .
                                       read_file($_) .
                                    "\n//INLINE $name END\n\n" .
                                    $opts->{'output'}{$area};
      }
   }

   undef
}


1;
