package Local::Kernel::Module;

use strict;
use warnings;

use re '/aa';

use Exporter qw(import);

use Local::File::C::Merge qw(merge_headers merge_sources);
use Local::C::Transformation qw(adapt);
use Local::GCC::Preprocess qw(
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


our @EXPORT_OK = qw(parse_sources);


sub _get_module_data
{
   my $dir = shift;

   my @kernel_includes;
   my $headers = merge_headers($dir, \@kernel_includes);
   my $code    = merge_sources($dir);

   @kernel_includes = map {"#include <$_>"} @kernel_includes;

   #getting list of kernel headers from *.c files; and remove others
   $code =~ s/^\h*\#\h*include\h*(?:(<[^>]+>)|("[^"]+"))\h*$/
               push @kernel_includes, "#include $1\n" if defined $1;''/meg;


   #remove includes, because they are already included
   if ($headers) {
      $headers =~ s/^\h*\#\h*include\h*[<"][^">]+[">]\h*$//mg;
      $code = $headers . $code;
   }

   (\$code, \@kernel_includes)
}

sub _get_kernel_data
{
   my $dir = shift;
   my $includes = join("\n", @{$_[0]});

   my $code  = preprocess_as_kernel_module($dir, $includes);
   my @macro = preprocess_as_kernel_module_get_macro($dir, $includes);

   @macro = grep ! /\A#define __STDC_(HOSTED_)?_\N+\Z/, @macro;


   (\$code, \@macro)
}

sub _preprocess_module_code
{
   my ($module_code, $kernel_macro, $directives) = @_;

   my $data =  join("\n", @$kernel_macro) .
               "\n//<special_mark>\n"     .
               join("\n", @$directives)   .
               "\n\n"                     .
               $$module_code;

   my $code = preprocess_directives($data);

   $code = substr($code,
                  index($code, '//<special_mark>') +
                  length('//<special_mark>') +
                  1
           );

   my @macro;
   $code =~ s/^\h*+(#\h*+define\N*+)\n/push @macro, $1;''/gme;
   $code =~ s/^\h*+(#\h*+undef\N*+)\n//gm;


   (\$code, \@macro)
}

sub _prepare_module_sources
{
   my ($kernel_dir, $module_dir, $directives) = @_;
   my ($kernel_code, $kernel_macro,
       $module_code, $module_macro);

   {
      my $kernel_includes;
      ($module_code, $kernel_includes) = _get_module_data($module_dir);
      ($kernel_code, $kernel_macro)    = _get_kernel_data($kernel_dir, $kernel_includes);
   }

   ($module_code, $module_macro) = _preprocess_module_code($module_code, $kernel_macro, $directives);

   ($kernel_macro, $kernel_code, $module_macro, $module_code)
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
      _prepare_module_sources(@_);

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
