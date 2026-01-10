package App::Extricate::Plugin::Spatch;

use Pod::Usage;
use Pod::Find qw(pod_where);
use warnings;
use strict;
use utf8::all;
use File::Which;
use Hash::Ordered;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::Spatch

Plugin::Spatch - run spatch on an extricated function

=head1 OPTIONS

=over 8

=item B<--plugin-spatch-file function^patch>

Apply a patch "patch" to an extricated function "function". If the
"function^" part will be omitted then patch will be applied to any
function. Please note, that if you use the --full option to extricate a
function B that calls a function A and use "A^patch.cocci"
configuration then patch.cocci will not be applied. In such a case
you should use "B^patch.cocci" configuration or just "patch.cocci".

=item B<--[no-]plugin-spatch-wait>

Wait until spatch will finish to work. Will wait by default.

=item B<--plugin-spatch-help>

Display this information.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my @files;
   my $help = 0;
   my $wait = 1;

   GetOptions(
      'plugin-spatch-file=s' => \@files,
      'plugin-spatch-wait!'  => \$wait,
      'plugin-spatch-help'   => \$help,
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
         -msg     => "Option --plugin-spatch-file should be provided.\n",
         -exitval => 1
      }
   ) unless @files;

   die "Please, install coccinelle package.\n"
     unless which('spatch');

   @files = reverse @files;

   my $cocci = Hash::Ordered->new();
   foreach (@files) {
      chomp;
      my $fmask = '#ALL';
      my $file  = $_;
      if (m/\A(?<mask>[\w_*.+?]++)\^(?<file>.*)\Z/) {
         $fmask = $+{mask};
         $file  = $+{file};
      }

      unless (-f $file && -r _) {
         die "FAIL: Can't access file $file.\n";
      }

      $cocci->set($fmask => [@{$cocci->get($fmask) // []}, $file]);
   }

   $config->{'spatch'} = $cocci;

   bless {cocci => $cocci, wait => $wait}, $self;
}

sub level
{
   post_output => 70;
}

sub action
{
   my ($self, $opts) = @_;
   my $cocci = $self->{cocci};
   my $func  = $opts->{function};

   return undef
     if !(exists $opts->{'dir'}) || !(exists $opts->{'file'});

   my @patches;
   foreach ($cocci->keys) {
      if ($func =~ $_) {
         push @patches, @{$cocci->get($_)};
      } elsif ($_ eq '#ALL') {
         push @patches, @{$cocci->get($_)};
      }
   }

   foreach my $patch (@patches) {
      my $cfile = (grep {m/\.c$/} @{$opts->{'file'}})[0];
      my @args  = ('--in-place', '--sp-file', $patch, $cfile);
      print "SPATCH: spatch @args\n";

      my $pid = fork();
      die "FAIL: can't fork $!"
        unless defined $pid;

      unless ($pid) {
         open(STDIN, '</dev/null');
         unless ($self->{wait}) {
            open(STDOUT, '>/dev/null');
            open(STDERR, '>&STDOUT');
         }
         exec('spatch', @args);
      }

      if ($self->{wait}) {
         waitpid $pid, 0;
         if ($?) {
            die "SPATCH: failed to apply the $patch with code $?\n";
         }
      }
   }

   undef;
}

1;
