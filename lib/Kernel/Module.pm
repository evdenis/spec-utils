package Kernel::Module;

use strict;
use warnings;
use utf8::all;

use re '/aa';

use Exporter qw(import);
use File::Spec::Functions qw(catfile);
use File::Basename qw(dirname);
use Cwd qw(realpath);
use Carp qw(croak);

use File::C::Merge qw(merge_headers merge_sources merge_all_files);
use File::Merge qw(merge);
use C::Util::Transformation qw(adapt);
use Local::List::Util qw(uniq);
use Kernel::Makefile qw(get_modules_deps);
use GCC::Preprocess qw(
  get_macro
  preprocess
  preprocess_directives_noincl
  preprocess_as_kernel_module
  preprocess_as_kernel_module_simpl
  preprocess_as_kernel_module_get_macro_simpl
  preprocess_as_kernel_module_directives
  preprocess_as_kernel_module_nocomments
);

use C::Macro;
use C::MacroSet;
use C::TypedefSet;
use C::StructureSet;
use C::EnumSet;
use C::FunctionSet;
use C::DeclarationSet;
use C::GlobalSet;
use C::AcslcommentSet;

our @EXPORT = qw(parse_sources);
our @EXPORT_OK =
  qw(prepare_module_sources_sep preprocess_module_sources_sep preprocess_module_sources preprocess_module_sources_nocomments prepare_module_sources);

sub __get_module_folder_c_contents
{
   my ($mdir, $kdir, $exact_module) = @_;
   my $code     = '';
   my $includes = [];

   $mdir = [$mdir]
     unless ref($mdir) eq 'ARRAY';

   foreach my $f (@{$mdir}) {
      my $is_file = 0;
      my $dir;
      if (-d $f) {
         $dir = $f;
      } elsif (-f $f) {
         $dir     = dirname $f;
         $is_file = 1;
      } else {
         croak "$f is not a file or a directory.";
      }
      push @{$includes}, $dir;

      my $makefile = catfile $dir, 'Makefile';
      if (-r $makefile) {
         my $files;
         my $module_includes;
         ($files, $module_includes) = get_modules_deps($makefile, $kdir);
         push @{$includes}, @{$module_includes};

         if (%$files) {
            my $mod;
            unless ($exact_module) {
               my @modules = reverse sort {@{$files->{$a}} <=> @{$files->{$b}}} keys %$files;
               $mod = $modules[0];
            } else {
               $mod = $exact_module;

               croak("Can't find module $mod in Makefile.\n")
                 unless exists $files->{$mod};
            }
            my @cfiles = @{$files->{$mod}};
            @cfiles = grep {$_ eq $f} @cfiles
              if $is_file;
            goto FALLBACK
              unless @cfiles;
            $code .= merge(uniq @cfiles);
         } else {
            goto FALLBACK;
         }
      } else {
       FALLBACK:
         warn "Can't find or parse module Makefile. Will use all *.c files.\n";
         my $upd_code = merge_sources($f);
         unless ($upd_code) {
            $upd_code = merge_all_files($f);
         }
         $code .= $upd_code;
      }
   }

   (\$code, $includes);
}

sub _get_module_data
{
   my ($mdir, $kdir, $exact_module) = @_;
   my @kernel_includes;
   my $headers = merge_headers($mdir, \@kernel_includes);
   my ($code, undef) = __get_module_folder_c_contents($mdir, $kdir, $exact_module);

   @kernel_includes = map {"#include <$_>"} @kernel_includes;

   #getting list of kernel headers from *.c files; and remove others
   $$code =~ s/^\h*\#\h*include\h*(?:(<[^>]+>)|("[^"]+"))/
               push @kernel_includes, "#include $1" if defined $1;''/meg;

   #remove includes, because they are already included
   if ($headers) {
      $headers =~ s/^\h*\#\h*include\h*[<"][^">]+[">]//mg;
      $code = $headers . $$code;
   }

   (\$code, \@kernel_includes);
}

sub _get_kernel_data
{
   my $dir      = shift;
   my $includes = join("\n", @{$_[0]});

   my $code  = preprocess_as_kernel_module_simpl($dir, \$includes);
   my $macro = preprocess_as_kernel_module_get_macro_simpl($dir, \$includes, 1);

   @$macro = grep !/\A#define __STDC_(HOSTED_)?_\N*\Z/, @$macro;

   ($code, $macro);
}

sub _preprocess_module_directives
{
   my ($kernel_macro, $defines, $module_code) = @_;

   my $additional = join("\n", @$kernel_macro) . "\n\n" . join("\n", @$defines);

   #returns reference
   my $code = preprocess_directives_noincl($module_code, \$additional);

   my @macro;
   $$code =~ s/^\h*+(#\h*+define\N*+)\n/push @macro, $1;''/gme;
   $$code =~ s/^\h*+(#\h*+undef\N*+)\n//gm;

   ($code, \@macro);
}

sub _preprocess_module_code
{
   #FIXME: undef instead of \@macro. Unneeded.
   #May be implemented with get_macro.
   (preprocess(\join("\n", @{$_[0]}, @{$_[1]}, ${$_[2]})), undef);
}

sub _generic_handle_sources_sep
{
   my ($kernel_dir, $module_dir, $exact_module, $defines, $pr_handler) = @_;
   my ($kernel_code, $kernel_macro, $module_code, $module_macro);

   {
      my $kernel_includes;
      ($module_code, $kernel_includes) = _get_module_data($module_dir, $kernel_dir, $exact_module);
      ($kernel_code, $kernel_macro) = _get_kernel_data($kernel_dir, $kernel_includes);
   }

   ($module_code, $module_macro) = $pr_handler->($kernel_macro, $defines, $module_code);

   ($kernel_macro, $kernel_code, $module_macro, $module_code);
}

sub prepare_module_sources_sep
{
   _generic_handle_sources_sep(@_, \&_preprocess_module_directives);
}

sub preprocess_module_sources_sep
{
   _generic_handle_sources_sep(@_, \&_preprocess_module_code);
}

sub _generic_handle_sources
{
   my ($kdir, $mdir, $exact_module, $defines, $func) = @_;

   $kdir = realpath $kdir;
   if (ref $mdir eq 'ARRAY') {
      $mdir = [map {realpath $_ } @{$mdir}];
   } else {
      $mdir = realpath $mdir;
   }

   my ($code, $includes) = __get_module_folder_c_contents($mdir, $kdir, $exact_module);

   my @sorted_includes = uniq @$includes;
   @sorted_includes = reverse sort @sorted_includes;
   #FIXME: /include should go last in the same level path sequence
   #because we need special handling for #include ""

   $defines = join("\n", @$defines) . "\n"
     if $defines;

   my ($o, $f) = $func->(realpath($kdir), \@sorted_includes, $code, \$defines);

   my $kernel_code;
   my $module_code;
   {
      my @mo;
      my @ko;

    NEXT:
      foreach my $file (@$o) {
         foreach my $i (@sorted_includes) {
            if (index($file, $i) == 0) {
               push @mo, $file;
               next NEXT;
            }
         }
         if ($file eq '<stdin>') {
            push @mo, $file;
         } else {
            push @ko, $file;
         }
      }

      $module_code = join("\n", map {$f->{$_} // ''} @mo);
      $kernel_code = join("\n", map {$f->{$_} // ''} @ko);
   }

   (\$kernel_code, \$module_code);
}

#-E and keep comments
sub preprocess_module_sources
{
   push @_, \&preprocess_as_kernel_module;
   goto \&_generic_handle_sources;
}

#-E
sub preprocess_module_sources_nocomments
{
   push @_, \&preprocess_as_kernel_module_nocomments;
   goto \&_generic_handle_sources;
}

#-E, keep comments and don't expand macro definitions except compilation directives
sub prepare_module_sources
{
   push @_, \&preprocess_as_kernel_module_directives;
   goto \&_generic_handle_sources;
}

sub __generic_parse
{
   no strict 'refs';

   my $call = sub {goto &{$_[0]->can('parse')}};

   foreach my $k (keys %{$_[0]}) {
      my $class = "C::\u${k}Set";
      print "\u$_[1] ${class} parse\n";

      $_[0]->{$k} = $call->($class, $_[0]->{$k}, $_[1]);
   }
}

sub _parse_module_part
{
   my $module_code = $_[0];
   my (%module, @comments, @strings);

   adapt($$module_code, comments => \@comments, strings => \@strings);

   my @module_macro;
   my $macro_re = qr/^\h*+#\h*+define.*+\n/m;
   $$module_code =~ s/$macro_re/push @module_macro, ${^MATCH}; ''/gmep;

   adapt($$module_code, macro => 1);

   %module = map {$_ => $module_code} qw(typedef enum structure global declaration function)
     if $$module_code;

   $module{macro}       = \@module_macro;
   $module{acslcomment} = \@comments;

   __generic_parse(\%module, 'module');

   (\%module, \@comments, \@strings);
}

sub _parse_kernel_part
{
   my ($kernel_code, $full_kernel, $preprocess) = @_;
   my %kernel;
   my @strings;

   my $kernel_macro = get_macro($kernel_code, 1);
   $kernel_code = preprocess($kernel_code)
     if $preprocess;

   #remove attributes
   my %remove = (attributes => 1);
   $remove{strings} = \@strings;
   unless ($preprocess) {
      $remove{comments} = 1;
      $remove{macro}    = 1;
   }
   adapt($$kernel_code, \%remove);

   if ($$kernel_code) {
      my @types = qw(typedef enum structure global declaration);
      push @types, 'function'
        if $full_kernel;
      %kernel = map {$_ => $kernel_code} @types;
   }

   $kernel{macro} = $kernel_macro;

   __generic_parse(\%kernel, 'kernel');

   (\%kernel, \@strings);
}

sub parse_sources
{
   my $full_kernel  = pop @_;
   my $kernel_parse = pop @_;
   my ($kernel_code, $module_code) = prepare_module_sources(@_);

   my %ret;
   @ret{qw(kernel kernel_strings module comments module_strings)} = (
      ($kernel_parse ? _parse_kernel_part($kernel_code, $full_kernel, 1) : (undef, undef)),
      _parse_module_part($module_code)
   );

   %ret;
}

1;
