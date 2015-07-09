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
   my @text;

   GetOptions(
      'plugin-inline-file=s' => \@inline,
      'plugin-inline-text=s' => \@text,
   ) or die("Error in command line arguments\n");

   die "Option --plugin-inline-file or --plugin-inline-text should be provided.\n"
      unless @inline || @text;

   my %inline;
   foreach (@inline) {
      chomp;
      if (m/\A(begin|end)\^([a-zA-Z_]\w+|\d)\^(.*)\Z/) {
         my ($pos, $area, $path) = ($1, $2, $3);
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

         push @{ $inline{$area}{$pos} }, $path
      } else {
         die "Can't parse inline id '$_'\n"
      }
   }
   my %text;
   foreach (@text) {
      chomp;
      if (m/\A(begin|end)\^([a-zA-Z_]\w+|\d)\^(.*)\Z/) {
         my ($pos, $area, $str) = ($1, $2, $3);
         if ($area =~ m/\A\d\Z/) {
            if ($area > 0 && $area < @Kernel::Module::Graph::out_order + 1) {
               $area = $Kernel::Module::Graph::out_order[$area - 1]
            } else {
               die "There is no such area $area\n"
            }
         } elsif (!exists $Kernel::Module::Graph::out_file{$area}) {
            die "There is no such area $area\n"
         }

         push @{ $text{$area}{$pos} }, $str
      } else {
         die "Can't parse inline id '$_'\n"
      }
   }


   $config->{'inline'} = \%inline;

   bless { inline => \%inline, text => \%text }, $self
}

sub priority
{
   80
}

sub level
{
   'raw_data'
}

sub action
{
   my ($self, $opts) = @_;

   return undef
      unless exists $opts->{output} && exists $opts->{output_dir};

   foreach my $area (keys %{$self->{inline}}) {
      foreach (@{$self->{inline}{$area}{begin}}) {
         my $name = basename $_;
         print "plugin: inline: $area: begin: '$name'\n";

         $opts->{'output'}{$area} = "\n//INLINE $name BEGIN\n\n" .
                                       read_file($_) .
                                    "\n//INLINE $name END\n\n" .
                                    $opts->{'output'}{$area};
      }
      foreach (@{$self->{inline}{$area}{end}}) {
         my $name = basename $_;
         print "plugin: inline: $area: end: '$name'\n";

         $opts->{'output'}{$area} = $opts->{'output'}{$area} .
                                    "\n\n//INLINE $name BEGIN\n\n" .
                                       read_file($_) .
                                    "\n//INLINE $name END\n";
      }
   }

   foreach my $area (keys %{$self->{text}}) {
      foreach (@{$self->{text}{$area}{begin}}) {
         print "plugin: inline: $area: begin: $_\n";
         $opts->{'output'}{$area} = "$_\n" .
                                    $opts->{'output'}{$area};
      }
      foreach (@{$self->{text}{$area}{end}}) {
         print "plugin: inline: $area: end: $_\n";
         $opts->{'output'}{$area} = $opts->{'output'}{$area} .
                                    "$_\n";
      }
   }

   undef
}


1;
