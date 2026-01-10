package App::Extricate::Plugin::SmartLib;

use warnings;
use strict;
use utf8::all;

use Pod::Usage;
use Pod::Find qw(pod_where);
use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);
use Kernel::Module::Graph;
use File::Slurp qw(read_file);
use File::Basename;
use C::DeclarationSet;
use C::Util::Transformation qw(adapt restore);

=encoding utf8

=pod

=head1 Plugin::SmartLib

Plugin::SmartLib - selectively include ACSL specifications from functions
declarations in a file to the output

=head1 OPTIONS

=over 8

=item B<--plugin-smartlib-file file>

The plugin reads the library file then parses functions declarations and
their contracts. If there is a function call to one of the functions from
the library file, then the declaration with the specification for this
function will be included in the output.

=item B<--plugin-smartlib-help>

Display this information.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my $help = 0;
   my $file;

   GetOptions(
      'plugin-smartlib-file=s' => \$file,
      'plugin-smartlib-help'   => \$help,
   ) or die("Error in command line arguments\n");

   my $input = pod_where({-inc => 1}, __PACKAGE__);
   pod2usage(
      {
         -input   => $input,
         -verbose => 2,
         -exitval => 0
      }
   ) if $help;

   chomp $file;

   pod2usage(
      {
         -input   => $input,
         -msg     => "Option --plugin-smartlib-file should be provided.\n",
         -exitval => 1
      }
   ) unless $file;

   die "Can't read file $file\n"
     unless -r $file;

   my @specs;
   $file = read_file($file, scalar_ref => 1);
   adapt($$file, comments => \@specs, macro => 1);
   my $data = C::DeclarationSet->parse($file, 'unknown');

   $config->{'smartlib'}      = $data;
   $config->{'smartlib-spec'} = \@specs;

   bless {smartlib => $data, specs => \@specs}, $self;
}

sub level
{
   return (
      'reduced_graph' => 70,
      'raw_data'      => 70
   );
}

sub action
{
   my ($self, $opts) = @_;

   if ($opts->{level} eq 'reduced_graph') {
      goto &action_check_graph;
   } elsif ($opts->{level} eq 'raw_data') {
      goto &action_output;
   } else {
      die "plugin: smartlib: should not be called from level $opts->{level}\n";
   }

   undef;
}

sub action_check_graph
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{graph};

   print "plugin: smartlib: checking kernel functions\n";
   my $graph        = $opts->{graph};
   my $check_exists = sub {
      foreach ($graph->vertices) {
         return 1 if $graph->get_vertex_attribute($_, 'object')->name eq $_[0];
      }
      0;
   };

   my $file = '';
   foreach (@{$self->{smartlib}{set}}) {
      if ($check_exists->($_->name)) {
         $file .= $_->to_string($self->{specs}) . "\n\n";
      }
   }
   restore($file, comments => $self->{specs});
   $self->{file} = \$file;

   undef;
}

sub action_output
{
   my ($self, $opts) = @_;

   return undef
     unless exists $opts->{output} && exists $self->{file};

   print "plugin: smartlib: adding library specifications\n";
   $opts->{'output'}{module_c} = ${$self->{file}} . "\n\n" . $opts->{output}{module_c};

   undef;
}

1;
