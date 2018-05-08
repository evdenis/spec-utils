package Kernel::Makefile;

use warnings;
use strict;

use re '/aa';

use RE::Common qw($varname);
use Local::String::Util qw(normalize);
use File::Slurp qw(read_file);
use File::Spec::Functions qw(catfile splitpath);
use Cwd qw(realpath);

use Exporter qw(import);

our @EXPORT = qw(get_modules_deps);

sub get_modules_deps
{
   my $file    = $_[0];
   my $kdir    = $_[1];
   my $makedir = (splitpath($file))[1];
   my $data    = read_file($file, scalar_ref => 1);
   my @modules;
   my @includes;

   while (
      $$data =~ m/
                        obj-(?:\$\($varname\)|[mny])
                        \h*+
                           [:+]?=
                        \h*+
                        (?<modules>
                           (?<body>
                              [^\\\n]*+
                              \\\n
                              (?&body)?
                           )?
                           .++
                        )
                        $
                     /gmx
     )
   {
      push @modules, map {/\.o\Z/ ? substr($_, 0, -2) : ()} split /\s++/, $+{modules};
   }

   my %struct;
   foreach my $module (@modules) {
      while (
         $$data =~ m/
                           \b${module}-(?:y|objs(?:-y|-\$\(CONFIG_\w++\))?)
                           \h*+
                              [:+]?=
                           \h*+
                           (?<deps>
                              (?<body>
                                 [^\\\n]*+
                                 \\\n
                                 (?&body)?
                              )?
                              .++
                           )
                           $
                          /gmx
        )
      {
         push @{$struct{$module}}, map {realpath(catfile($makedir, substr($_, 0, -2) . '.c'))}
           grep {/\.o\Z/}
           split /\s++/, $+{deps} =~ tr/\\//dr;
      }
   }

   if (
      $$data =~ m/ccflags-y\h*+[:+]?=\h*+
                        (?<ccflags>
                           (?<body>
                              [^\\\n]*+
                              \\\n
                              (?&body)?
                           )?
                           .++
                        )
                        $/mx
     )
   {
      my $ccflags = $+{ccflags};
      while ($ccflags =~ m/-I\h*+([^\s]++)/g) {
         my $include = $1;
         if ($include =~ s!\A\$\(src(?:tree)?\)/?!!) {
            $include = catfile($kdir, $include);
         }
         push @includes, $include;
      }
   }

   (\%struct, \@includes);
}

1;
