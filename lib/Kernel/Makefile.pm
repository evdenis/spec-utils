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
   my $data = read_file($_[0], scalar_ref => 1);
   my @modules;

   while ( $$data =~ m/
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
                     /gmx ) {
      push @modules, map {/\.o\Z/ ? substr($_, 0, -2) : ()} split /\s++/, $+{modules};
   }

   my %struct;
   foreach my $module (@modules) {
      while ( $$data =~ m/
                           ${module}-(?:y|objs)
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
                          /gmx ) {
         push @{ $struct{$module} },
            map { realpath(catfile((splitpath($_[0]))[1], substr($_, 0, -2) . '.c')) }
            grep { /\.o\Z/ }
            split /\s++/, $+{deps} =~ tr/\\//dr;
      }
   }

   \%struct
}


1;
