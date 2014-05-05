package Local::Kernel::Module;

use strict;
use warnings;

use re '/aa';

use Exporter qw(import);

use Local::File::C::Merge qw(merge_headers);
use Local::File::Merge qw(merge);
use Local::C::Transformation qw(adapt);
use Local::Kernel::Makefile qw(get_modules_deps);
use Local::GCC::Preprocess qw(
      preprocess
      preprocess_directives
      preprocess_as_kernel_module
      preprocess_as_kernel_module_get_macro
);

use C::Macro;
use C::MacroSet;
use C::TypedefSet;
use C::StructureSet;
use C::EnumSet;
use C::FunctionSet;
use C::DeclarationSet;
use C::GlobalSet;


our @EXPORT = qw(parse_sources);
our @EXPORT_OK = qw(prepare_module_sources preprocess_module_sources);


sub _get_module_data
{
   my $dir = shift;

   my @kernel_includes;
   my $headers = merge_headers($dir, \@kernel_includes);
   my $code    = merge(map {@{$_}} values get_modules_deps("$dir/Makefile")); # Just use them all

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

   my $code  = preprocess_as_kernel_module($dir, \$includes);
   my $macro = preprocess_as_kernel_module_get_macro($dir, \$includes, 1);

   @$macro = grep ! /\A#define __STDC_(HOSTED_)?_\N+\Z/, @$macro;


   ($code, $macro)
}

sub _preprocess_module_directives
{
   my ($kernel_macro, $defines, $module_code) = @_;

   my $data =  join("\n", @$kernel_macro) .
               "\n//<special_mark>\n"     .
               join("\n", @$defines)      .
               "\n\n"                     .
               $$module_code;

   #returns reference
   my $code = preprocess_directives(\$data);

   #scalar
   $code = substr($$code,
                  index($$code, '//<special_mark>') +
                  length('//<special_mark>') +
                  1
           );

   my @macro;
   $code =~ s/^\h*+(#\h*+define\N*+)\n/push @macro, $1;''/gme;
   $code =~ s/^\h*+(#\h*+undef\N*+)\n//gm;


   (\$code, \@macro)
}

sub _preprocess_module_code
{
   #FIXME: undef instead of \@macro. Unneeded.
   #May be implemented with get_macro.
   ( preprocess(\join("\n", @{$_[0]}, @{$_[1]}, ${$_[2]})), undef )
}

sub _generic_handle_sources
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

sub prepare_module_sources
{
   _generic_handle_sources(@_, \&_preprocess_module_directives)
}

sub preprocess_module_sources
{
   _generic_handle_sources(@_, \&_preprocess_module_code)
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

sub parse_sources
{
   my ($kernel_macro, $kernel_code, $module_macro, $module_code) =
      prepare_module_sources(@_);

   #remove attributes
   adapt($$kernel_code, attributes => 1);
   my @comments;
   adapt($$module_code, comments => \@comments);


   my %kernel = map { $_ => $kernel_code } qw(typedef enum structure global declaration)
      if $$kernel_code;

   $kernel{macro} = $kernel_macro
      if @$kernel_macro;

   my %module = map { $_ => $module_code } qw(typedef enum structure global function)
      if $$module_code;

   $module{macro} = $module_macro
      if @$module_macro;

   __generic_parse(\%kernel, 'kernel');
   __generic_parse(\%module, 'module');

   (module => \%module, kernel => \%kernel, comments => \@comments)
}


1;
