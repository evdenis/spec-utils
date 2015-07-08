package App::Dismember::Plugin::Include;

use warnings;
use strict;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Basename;
use File::Spec::Functions qw(catfile);
use File::Copy;
use Cwd qw(abs_path);

sub process_options
{
   my ($self, $config) = @_;
   my @include;
   my $link = 1;

   GetOptions(
      'plugin-include-file=s' => \@include,
      'plugin-include-link!'  => \$link,
   ) or die("Error in command line arguments\n");

   die "Option --plugin-include-file should be provided.\n"
      unless @include;

   my %include;
   foreach (@include) {
      chomp;
      if (m/\A([a-zA-Z_]\w+|\d)\^(.*)\Z/) {
         my ($area, $path) = ($1, $2);
         if ($area =~ m/\A\d\Z/) {
            if ($area > 0 && $area < @Kernel::Module::Graph::out_order + 1) {
               $area = $Kernel::Module::Graph::out_order[$area - 1]
            } else {
               die "There is no such area $area\n"
            }
         } elsif (!exists $Kernel::Module::Graph::out_file{$area}) {
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

   bless { include => \%include, base_dir => $config->{output_dir}, link => $link }, $self
}

sub priority
{
   90
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
         my $old = abs_path $_;
         my $new = catfile($opts->{output_dir}, $include);
         if ($self->{link}) {
            symlink $old, $new;
            print "plugin: include: link $old -> $new\n";
         } else {
            copy($old, $new);
            print "plugin: include: copy $old -> $new\n";
         }

         $opts->{'output'}{$area} = qq(#include "$include"\n\n) .
                                 $opts->{'output'}{$area};
      }
   }

   undef
}


1;
