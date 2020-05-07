package App::Extricate::Plugin::FramaC;

use Pod::Usage;
use Pod::Find qw(pod_where);
use warnings;
use strict;
use File::Slurp qw(write_file);
use File::Which;
use Hash::Ordered;

use Getopt::Long qw(:config gnu_compat permute no_getopt_compat pass_through);

=encoding utf8

=pod

=head1 Plugin::FramaC

Plugin::FramaC - run Frama-C on an extricated file. By default the cli will be used
"frama-c -wp -wp-rte -wp-model "Typed+Cast" -wp-prover alt-ergo,cvc4,z3 extricated_file.c"

=head1 OPTIONS

=over 8

=item B<--plugin-framac function^cli_arguments>

Run Frama-C on a "function" with command line arguments "cli_arguments".
If the "function^" part will be omitted then "cli_arguments" will be used
as default for any function. Please note, that if you use the --full option
to extricate a function B ("Bcli_arguments") that calls a function A
("Acli_arguments") then the option "Bcli_arguments" will be applied despite
the file contains also the function A.

=item B<--[no-]plugin-framac-verbose>

Print full output of Frama-C to stdout. By default the tool prints only
verification status in case WP or Jessie plugins are used.

=item B<--[no-]plugin-framac-verdicts>

Output the list of verification verdicts (WP/Jessie) at the end. Enabled by default.
Applicable to WP/Jessie plugins output.

=item B<--plugin-framac-verdicts-file file>

Output the list of verification verdicts (WP/Jessie) to the file "file".
Applicable to WP/Jessie plugins output.

=item B<--plugin-framac-help>

Display this information.

=back

=cut

sub process_options
{
   my ($self, $config) = @_;
   my @configs;
   my $verbose        = 0;
   my $help           = 0;
   my $print_verdicts = 1;
   my $verdicts_file;

   GetOptions(
      'plugin-framac=s'               => \@configs,
      'plugin-framac-verbose!'        => \$verbose,
      'plugin-framac-verdicts!'       => \$print_verdicts,
      'plugin-framac-verdicts-file=s' => \$verdicts_file,
      'plugin-framac-help'            => \$help,
   ) or die("Error in command line arguments\n");

   my $input = pod_where({-inc => 1}, __PACKAGE__);
   pod2usage(
      {
         -input   => $input,
         -verbose => 2,
         -exitval => 0
      }
   ) if $help;

   die "Please, install Frama-C package.\n"
     unless which('frama-c');

   @configs = reverse @configs;

   my $framac = Hash::Ordered->new();
   foreach (@configs) {
      chomp;
      my $fmask  = '#ALL';
      my $config = $_;
      if (m/\A(?<mask>[\w_*.+?]++)\^(?<config>.*)\Z/) {
         $fmask  = $+{mask};
         $config = $+{config};
      }
      $framac->set($fmask => $config);
   }

   unless ($framac->exists('#ALL')) {
      my $default = ' -wp -wp-rte -wp-model "Typed+Cast" -wp-prover alt-ergo,cvc4,z3 ';
      warn "FRAMA-C: default configuration will be '$default'\n";
      $framac->set('#ALL' => $default);
   }

   $config->{'framac'} = $framac;

   bless {
      framac         => $framac,
      verbose        => $verbose,
      verdicts_file  => $verdicts_file,
      print_verdicts => $print_verdicts
   }, $self;
}

sub level
{
   return (
      post_output => 80,
      before_exit => 90
   );
}

sub action
{
   my ($self, $opts) = @_;

   if ($opts->{level} eq 'post_output') {
      goto &action_run_framac;
   } elsif ($opts->{level} eq 'before_exit') {
      goto &action_output_verdicts;
   } else {
      die "plugin: framac: should not be called from level $opts->{level}\n";
   }
}

our %VERDICT;

our %STATUS = (
   'INSTRUMENT FAIL'  => -1,
   'NOSPEC'           => 0,
   'UNPROVED'         => 1,
   'PARTIALLY PROVED' => 2,
   'PROVED'           => 3
);

sub action_output_verdicts
{
   my ($self, $opts) = @_;

   if (%VERDICT && ($self->{print_verdicts} || $self->{verdicts_file})) {
      my @keys   = sort {$STATUS{$VERDICT{$a}{status}} <=> $STATUS{$VERDICT{$b}{status}} || $a cmp $b} keys %VERDICT;
      my $output = join(
         "\n",
         map {
            "VERDICT: $_ $VERDICT{$_}{status}"
              . ($VERDICT{$_}{proved} ? " ($VERDICT{$_}{proved}/$VERDICT{$_}{total})" : "")
         } @keys
      ) . "\n";

      print "---VERDICTS---\n" . $output
        if $self->{print_verdicts};
      write_file($self->{verdicts_file}, $output)
        if $self->{verdicts_file};
   }
}

sub process_output
{
   my ($output, $func, $verbose) = @_;
   my $result = '';

   $result .= "VERDICT: $func ";

   my $strategy_scheduled = 0;

   $strategy_scheduled = 1
     if $output =~ m/(?<goals>\d++)\h++goals?\h++scheduled/;

   if (!$strategy_scheduled || $+{goals} == 0) {
      $result .= "NOSPEC\n";
      $VERDICT{$func} = {status => 'NOSPEC'};
   } elsif ($output =~ m!Proved goals:\h*+(?<proved>\d+)\h*+/\h*+(?<total>\d+)!) {
      my $begin  = $-[0];
      my $proved = $+{proved};
      my $total  = $+{total};

      if ($proved == $total) {
         $result .= "PROVED\n";
         $VERDICT{$func} = {status => 'PROVED'};
      } elsif ($proved <= $total) {
         my $report = substr($output, $begin);
         if ($proved == 0) {
            $result .= "UNPROVED\n";
            $VERDICT{$func} = {status => 'UNPROVED'};
         } else {
            $result .= "PARTIALLY PROVED (${proved}/${total})\n";
            $VERDICT{$func} = {status => 'PARTIALLY PROVED', proved => $proved, total => $total};
         }
         $result .= "<--\n$report\n-->\n" unless $verbose;
      } else {
         return '';    # ERROR
      }
   } elsif ($output =~ m/All goals are proved/) {
      $result .= "PROVED\n";
   } else {
      return '';       # ERROR
   }

   return $result;
}

sub action_run_framac
{
   my ($self, $opts) = @_;
   my $framac  = $self->{framac};
   my $verbose = $self->{verbose};
   my $func    = $opts->{function};

   return undef
     if !(exists $opts->{'dir'}) || !(exists $opts->{'file'});

   my $cli_args = $framac->get('#ALL');
   foreach my $mask ($framac->keys) {
      if ($func =~ $mask) {
         $cli_args = $framac->get($mask);
         last;
      }
   }

   my $cfile = (grep {m/\.c$/} @{$opts->{'file'}})[0];
   my $is_deductive = ($cli_args =~ m/-(?:wp|jessie|av)\b/);

   $cli_args .= " $cfile";
   print "FRAMA-C: frama-c $cli_args\n";

   my $output = qx(frama-c $cli_args 2>&1);

   if ($?) {
      $VERDICT{$func} = {status => 'INSTRUMENT FAIL'};
      print "VERDICT: $func INSTRUMENT FAIL\n" if $is_deductive;
      die "FRAMA-C: failed to run with code $?: $!\n" . ($output // '');
   }

   if ($is_deductive) {
      my $result = process_output($output, $func, $verbose);
      if ($verbose || !$result) {
         print $output;
         print $result if $result;
      } else {
         print $result;
      }
   } else {
      print $output;
   }

   undef;
}

1;
