package GCC::Preprocess;

use strict;
use warnings;

use re '/aa';

use Exporter qw(import);
use IPC::Open2;
use Carp;
use Cwd qw(realpath);
use Configuration qw(
  use_stdlib
  get_include_paths
  add_defines
  add_includes
);

use constant SPECIAL_MARK => '#pragma <special_mark>';

our @EXPORT_OK = qw(
  get_macro
  preprocess
  preprocess_directives_noincl
  preprocess_directives
  preprocess_as_kernel_module
  preprocess_as_kernel_module_simpl
  preprocess_as_kernel_module_nocomments
  preprocess_as_kernel_module_directives
  preprocess_as_kernel_module_get_macro_simpl
);

sub call_gcc
{
   my ($gcc_args, $code, $wantarray) = @_;
   my @res;
   my $res = '';

   my $pid = open2(\*GCC_OUT, \*GCC_IN, "gcc $gcc_args -");
   print GCC_IN $$code;
   close GCC_IN;

   if ($wantarray) {
      chomp(@res = <GCC_OUT>);
   } else {
      $res .= $_ while <GCC_OUT>;
   }

   close GCC_OUT;
   waitpid($pid, 0);
   if ($?) {
      my $exit_code = $? >> 8;
      my $signal = $? & 127;
      my $error_msg = "GCC preprocessing failed";
      $error_msg .= " with exit code $exit_code" if $exit_code;
      $error_msg .= " (signal $signal)" if $signal;
      die("$error_msg.\n");
   }

   return $wantarray ? \@res : \$res;
}

sub get_macro
{
   call_gcc('-dM -E -P -nostdinc', @_);
}

sub preprocess
{
   call_gcc('-E -P -nostdinc', @_);
}

use constant ARRAY => ref [];
my $include_re   = qr|#\h*+include\h*+[<"][^">]++[">]|;
my $include_mark = "//<ci_$$>";

sub _comment_includes
{
   ${$_[0]} =~ s|^\K(?=\h*+${include_re})|$include_mark|mg;
}

sub _uncomment_includes
{
   my $re = qr|^\K\Q${include_mark}\E(?=\h*+${include_re})|m;
   if ((ref $_[0]) eq ARRAY) {
      s/$re// foreach @{$_[0]};
   } else {
      ${$_[0]} =~ s/$re//g;
   }
}

#excluding include directives
sub preprocess_directives_noincl
{
   my $code = ($_[1] ? ${$_[1]} : '') . "\n" . SPECIAL_MARK . "\n" . ${$_[0]};

   _comment_includes(\$code);

   $code = call_gcc('-E -P -C -fdirectives-only ' . use_stdlib(), \$code, $_[2]);

   _uncomment_includes($code);

   if ($_[2]) {
      my $ind = -1;
      for (my $i = 0; $i < $#$code; ++$i) {
         if ($code->[$i] eq SPECIAL_MARK) {
            $ind = $i;
            last;
         }
      }
      die("Internal error. Can't find marker") if $ind == -1;

      [splice(@$code, $ind + 1)];
   } else {
      \substr($$code, index($$code, SPECIAL_MARK) + length(SPECIAL_MARK) + 1);
   }
}

sub _generic_preprocess_directives
{
   my %files;

   my $code = call_gcc(shift, \(($_[1] ? ${$_[1]} : '') . "\n" . SPECIAL_MARK . "\n" . ${$_[0]}), 1);

   my @order;
   {
      my $ready = 0;
      my $current_file;
      foreach (@$code) {
         $ready = 1, next
           if $_ eq SPECIAL_MARK;
         if (m/#\h++\d++\h++"([^"]++)"/) {
            $current_file = index($1, '<') != -1 ? $1 : realpath($1);
            push @order, $current_file;
            next;
         }

         push @{$files{$current_file}}, $_
           if $ready;
      }
   }

   {
      my %uniq;
      @order = reverse grep {exists $files{$_} && !$uniq{$_}++} reverse @order;
   }

   foreach (keys %files) {
      $files{$_} = join("\n", @{$files{$_}});
   }

   (\@order, \%files);
}

# code
# additional directives
sub preprocess_directives
{
   _generic_preprocess_directives('-E -CC -fdirectives-only ' . use_stdlib(), @_);
}

sub form_gcc_kernel_include_path
{
   my ($kdir_path) = @_;
   my $gcc_include_path;

   foreach (get_include_paths()) {
      $gcc_include_path .= "-I ${kdir_path}/${_} ";
   }

   my @str    = split "\n", qx(gcc -print-search-dirs);
   my $stdlib = substr($str[0], index($str[0], ': ') + 2) . 'include/';

   $gcc_include_path .= "-I $stdlib";

   $gcc_include_path;
}

# kernel directory
# include directories
# code
# additional defines
sub __generic_preprocess_as_kernel_module
{
   my ($kdir, $idir) = (shift, shift);

   return ([], {}) unless ${$_[0]};

   add_includes(${$_[0]});
   add_defines(${$_[0]});

   my $argline = pop @_;
   $argline .= ' ' . form_gcc_kernel_include_path($kdir);

   $argline .= " -I " . join(" -I ", @$idir) . " "
     if @$idir;

   _generic_preprocess_directives($argline, @_[0, 1]);
}

sub preprocess_as_kernel_module_directives
{
   push @_, '-E -CC -fdirectives-only ' . use_stdlib();
   goto \&__generic_preprocess_as_kernel_module;
}

sub preprocess_as_kernel_module
{
   push @_, '-E -CC ' . use_stdlib();
   goto \&__generic_preprocess_as_kernel_module;
}

sub preprocess_as_kernel_module_nocomments
{
   push @_, '-E ' . use_stdlib();
   goto \&__generic_preprocess_as_kernel_module;
}

sub preprocess_as_kernel_module_simpl
{
   unless (${$_[1]}) {
      return $_[2] ? [] : \undef;
   }

   add_includes(${$_[1]});
   add_defines(${$_[1]});
   call_gcc('-E -P ' . use_stdlib() . form_gcc_kernel_include_path($_[0]), @_[1, 2]);
}

sub preprocess_as_kernel_module_get_macro_simpl
{
   unless (${$_[1]}) {
      return $_[2] ? [] : \undef;
   }

   add_includes(${$_[1]});
   add_defines(${$_[1]});
   call_gcc('-dM -E -P ' . use_stdlib() . form_gcc_kernel_include_path($_[0]), @_[1, 2]);
}

1;
