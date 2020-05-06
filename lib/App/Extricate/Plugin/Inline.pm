package App::Extricate::Plugin::Inline;

use warnings;
use strict;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Slurp qw(read_file);
use File::Basename;

=encoding utf8

=pod

=head1 Plugin::Inline

Plugin::Inline - inlines data to the output files

=head1 OPTIONS

=over 8

=item B<--plugin-inline-file string>

The "string" argument is of format 'area^to_file^path', where the area is 'begin' or 'end',
the to_file is kernel_h(1), external_h(2), module_h(3), module_c(4), and the path is a valid
path to the desired include file with text you want to be inlined.

=item B<--plugin-inline-text string>

The "string" argument is of format 'area^to_file^text', where the area is 'begin' or 'end',
the to_file is kernel_h(1), external_h(2), module_h(3), module_c(4), and the text is a text
you want to be inlined.

=item B<--plugin-inline-help>

Display this information.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my @inline;
   my $help = 0;
   my @text;

   GetOptions(
      'plugin-inline-file=s' => \@inline,
      'plugin-inline-text=s' => \@text,
      'plugin-inline-help'   => \$help,
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
         -msg     => "Option --plugin-inline-file or --plugin-inline-text should be provided.\n",
         -exitval => 1
      }
   ) unless @inline || @text;

   my %inline;
   foreach (@inline) {
      chomp;
      if (m/\A(begin|end)\^([a-zA-Z_]\w+|\d)\^(.*)\Z/) {
         my ($pos, $area, $path) = ($1, $2, $3);
         if ($area =~ m/\A\d\Z/) {
            if ($area > 0 && $area < @Kernel::Module::Graph::out_order + 1) {
               $area = $Kernel::Module::Graph::out_order[$area - 1];
            } else {
               die "There is no such area $area\n";
            }
         } elsif (!exists $Kernel::Module::Graph::out_file{$area}) {
            die "There is no such area $area\n";
         }
         unless (-r $path) {
            die "Can't read file $path\n";
         }

         push @{$inline{$area}{$pos}}, $path;
      } else {
         die "Can't parse inline id '$_'\n";
      }
   }
   my %text;
   foreach (@text) {
      chomp;
      if (m/\A(begin|end)\^([a-zA-Z_]\w+|\d)\^(.*)\Z/) {
         my ($pos, $area, $str) = ($1, $2, $3);
         if ($area =~ m/\A\d\Z/) {
            if ($area > 0 && $area < @Kernel::Module::Graph::out_order + 1) {
               $area = $Kernel::Module::Graph::out_order[$area - 1];
            } else {
               die "There is no such area $area\n";
            }
         } elsif (!exists $Kernel::Module::Graph::out_file{$area}) {
            die "There is no such area $area\n";
         }

         push @{$text{$area}{$pos}}, $str;
      } else {
         die "Can't parse inline id '$_'\n";
      }
   }

   $config->{'inline'} = \%inline;

   bless {inline => \%inline, text => \%text}, $self;
}

sub level
{
   raw_data => 80;
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

         $opts->{'output'}{$area} =
           "\n//INLINE $name BEGIN\n\n" . read_file($_) . "\n//INLINE $name END\n\n" . $opts->{'output'}{$area};
      }
      foreach (@{$self->{inline}{$area}{end}}) {
         my $name = basename $_;
         print "plugin: inline: $area: end: '$name'\n";

         $opts->{'output'}{$area} =
           $opts->{'output'}{$area} . "\n\n//INLINE $name BEGIN\n\n" . read_file($_) . "\n//INLINE $name END\n";
      }
   }

   foreach my $area (keys %{$self->{text}}) {
      foreach (@{$self->{text}{$area}{begin}}) {
         print "plugin: inline: $area: begin: $_\n";
         $opts->{'output'}{$area} = "$_\n" . $opts->{'output'}{$area};
      }
      foreach (@{$self->{text}{$area}{end}}) {
         print "plugin: inline: $area: end: $_\n";
         $opts->{'output'}{$area} = $opts->{'output'}{$area} . "$_\n";
      }
   }

   undef;
}

1;
