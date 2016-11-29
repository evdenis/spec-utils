package Kernel::Module;

use strict;
use warnings;

use re '/aa';

use Exporter qw(import);
use File::Spec::Functions qw(splitpath catfile);
use Cwd qw(realpath);

use File::C::Merge qw(merge_headers merge_sources find_headers);
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
our @EXPORT_OK = qw(prepare_module_sources_sep preprocess_module_sources_sep preprocess_module_sources preprocess_module_sources_nocomments prepare_module_sources);

sub __get_module_folder_c_contents
{
   my $code;
   my $makefile = catfile $_[0], 'Makefile';
   if (-r $makefile) {
      my $files = get_modules_deps($makefile);
      if (%$files) {
         $code = merge(uniq map {@{$_}} values %$files) # Just use them all
      } else {
         goto FALLBACK
      }
   } else {
FALLBACK:
      $code = merge_sources($_[0])
   }

   #FIXME:
   $code
}

sub _get_module_data
{
   my $dir = shift;
   my @kernel_includes;
   my $headers = merge_headers($dir, \@kernel_includes);
   my $code = __get_module_folder_c_contents($dir);

   @kernel_includes = map {"#include <$_>"} @kernel_includes;

   #getting list of kernel headers from *.c files; and remove others
   $code =~ s/^\h*\#\h*include\h*(?:(<[^>]+>)|("[^"]+"))/
               push @kernel_includes, "#include $1" if defined $1;''/meg;

   #remove includes, because they are already included
   if ($headers) {
      $headers =~ s/^\h*\#\h*include\h*[<"][^">]+[">]//mg;
      $code = $headers . $code;
   }

   (\$code, \@kernel_includes)
}

sub _get_kernel_data
{
   my $dir = shift;
   my $includes = join("\n", @{$_[0]});

   my $code  = preprocess_as_kernel_module_simpl($dir, \$includes);
   my $macro = preprocess_as_kernel_module_get_macro_simpl($dir, \$includes, 1);

   @$macro = grep ! /\A#define __STDC_(HOSTED_)?_\N+\Z/, @$macro;

   ($code, $macro)
}

sub _preprocess_module_directives
{
   my ($kernel_macro, $defines, $module_code) = @_;

   my $additional = join("\n", @$kernel_macro) .
                    "\n\n"                     .
                    join("\n", @$defines);

   #returns reference
   my $code = preprocess_directives_noincl($module_code, \$additional);

   my @macro;
   $$code =~ s/^\h*+(#\h*+define\N*+)\n/push @macro, $1;''/gme;
   $$code =~ s/^\h*+(#\h*+undef\N*+)\n//gm;

   ($code, \@macro)
}

sub _preprocess_module_code
{
   #FIXME: undef instead of \@macro. Unneeded.
   #May be implemented with get_macro.
   ( preprocess(\join("\n", @{$_[0]}, @{$_[1]}, ${$_[2]})), undef )
}

sub _generic_handle_sources_sep
{
   my ($kernel_dir, $module_dir, $defines, $pr_handler) = @_;
   my ($kernel_code, $kernel_macro,
       $module_code, $module_macro);

   {
      my $kernel_includes;
      ($module_code, $kernel_includes) = _get_module_data($module_dir);
      ($kernel_code, $kernel_macro)    = _get_kernel_data($kernel_dir, $kernel_includes);
   }

   ($module_code, $module_macro) = $pr_handler->($kernel_macro, $defines, $module_code);

   ($kernel_macro, $kernel_code, $module_macro, $module_code)
}

sub prepare_module_sources_sep
{
   _generic_handle_sources_sep(@_, \&_preprocess_module_directives)
}

sub preprocess_module_sources_sep
{
   _generic_handle_sources_sep(@_, \&_preprocess_module_code)
}

sub _generic_handle_sources
{
   my ($kdir, $mdir, $defines, $func) = @_;

   $kdir = realpath $kdir;
   $mdir = realpath $mdir;

   my $code = __get_module_folder_c_contents($mdir);

   my %include_dirs;
   foreach(find_headers($mdir)) {
      $include_dirs{realpath((splitpath($_))[1])} = undef;
   }

   $defines = join("\n", @$defines) . "\n"
              if $defines;

   my ($o,$f) = $func->(
                     realpath($kdir),
                     [ keys %include_dirs ],
                     \$code,
                     \$defines
                );

   my $kernel_code;
   my $module_code;
   {
      my @mo;
      my @ko;

      foreach (@$o) {
         if (index($_, $mdir) != -1) {
            push @mo, $_
         } elsif ($_ eq '<stdin>') {
            push @mo, $_
         } else {
            push @ko, $_
         }
      }

      $module_code = join("\n", map { $f->{$_} // '' } @mo);
      $kernel_code = join("\n", map { $f->{$_} // '' } @ko);
   }


   (\$kernel_code, \$module_code)
}

#-E and keep comments
sub preprocess_module_sources
{
   push @_, \&preprocess_as_kernel_module;
   goto \&_generic_handle_sources
}

#-E
sub preprocess_module_sources_nocomments
{
   push @_, \&preprocess_as_kernel_module_nocomments;
   goto \&_generic_handle_sources
}

#-E, keep comments and don't expand macro definitions except compilation directives
sub prepare_module_sources
{
   push @_, \&preprocess_as_kernel_module_directives;
   goto \&_generic_handle_sources
}

sub __generic_parse
{
   no strict 'refs';

   my $call = sub { goto &{$_[0]->can('parse')} };

   foreach my $k (keys %{$_[0]}) {
      my $class = "C::\u${k}Set";
      print "\u$_[1] ${class} parse\n";

      $_[0]->{$k} = $call->($class, $_[0]->{$k}, $_[1])
   }
}

sub _parse_module_part
{
   my $module_code = $_[0];
   my (%module, @comments);

   adapt($$module_code, comments => \@comments);

   my @module_macro;
   my $macro_re = qr/^\h*+#\h*+define.*+\n/m;
   $$module_code =~ s/$macro_re/push @module_macro, ${^MATCH}; ''/gmep;

   adapt($$module_code, macro => 1);

   %module = map { $_ => $module_code } qw(typedef enum structure global declaration function)
      if $$module_code;

   $module{macro} = \@module_macro
      if @module_macro;

   $module{acslcomment} = \@comments
      if @comments;

   __generic_parse(\%module, 'module');

   (\%module, \@comments)
}

sub _parse_kernel_part
{
   my $kernel_code = $_[0];
   my %kernel;

   my $kernel_macro = get_macro($kernel_code, 1);
   $kernel_code = preprocess($kernel_code);

   #remove attributes
   adapt($$kernel_code, attributes => 1);

   %kernel = map { $_ => $kernel_code } qw(typedef enum structure global declaration)
      if $$kernel_code;

   $kernel{macro} = $kernel_macro
      if @$kernel_macro;

    __generic_parse(\%kernel, 'kernel');

    \%kernel
}

sub parse_sources
{
   my $kernel_parse = pop @_;
   my ($kernel_code, $module_code) =
      prepare_module_sources(@_);

   my %ret;
   @ret{qw/kernel module comments/} =
      (
         ($kernel_parse ? _parse_kernel_part($kernel_code) : undef),
         _parse_module_part($module_code)
      );

   %ret
}


1;
