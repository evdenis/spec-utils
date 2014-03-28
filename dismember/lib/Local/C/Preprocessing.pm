use Local::C::Preprocessing;

use warnings;
use strict;

use feature qw(switch);
use re '/aa';

use Exporter qw(import);

use Carp;

use Local::C::Transformation qw(:RE);
use Local::String::Utils qw(rtrim trim);

use C::Macro;
use C::MacroSet;


our @EXPORT = qw(preprocess_conditionals);


sub def_eval
{
   my $macro_set = shift;
   my $expr      = shift;
   my $exit = 0;

   $expr =~ s/defined(?:\s*+\((?<def1>[^)]+)\)|\s+(?<def1>[a-zA-Z_]\w*))/(\$macro_set->exists($+{def1}))/g;

   while ( $expr =~ m/
      (?:\(\$macro_set->exists\([^)]+\)\)) #ignore this part
      |\b(?<def2>[A-Za-z_]\w*)(?<args>\((?:(?>[^\(\)]+)|(?&args))*\))?/gx
   )
   {
      my ($begin, $end) = ($-[0], $+[0]);
      my $name = $+{def2};

      if (defined $name && $name ne 'UL') {
         my $val;

         if ($macro_set->exists($name)) {
            my $macro = $macro_set->get($name);
            if ($macro->args) {
               if (exists $+{args}) {
                  my $code = $macro->substitution;

                  if ($code) {
                     my @margs = @{ $macro->args };
                     my @args = map { trim($_) } split(/,/, $+{args} =~ s/^\(|\)$//gr);

                     if ($#args != $#margs) {
                        carp("Wrong number of macro arguments!");
                     }
                     foreach (0 .. $#args) {
                        $code =~ s/\Q$margs[$_]\E/$args[$_]/g;
                     }

                     $val = $code
                  }

               }
            } else {
               $val = $macro->substitution
            }
         } else {
            #gcc rule: if macro doesn't exists, use 0 instead
            $val = 0
         }

         if (defined $val) {
            substr($expr, $begin, $end - $begin, $val);
            pos($expr) = $begin
         }
      }
   }

   $expr =~ s/\b(\w+)\s*\#\#\s*(\w+)/${1}${2}/g;
   $expr =~ s/\b(\d+)\KU?L?//g;

   chomp $expr;
   my $res;

   $expr = '$res = ' . $expr . ';';

   eval $expr;
   croak($@) if ($@);

   return $res;
}


sub preprocess_conditionals
{
   my $macro_set = $_[1];
   my ($ncond, $ncond_rec) = (0, 0);
   
   my @preprocessed;
   my @lines = split /^/m, $_[0];

   my $def = qr/(?<def>[a-zA-Z_]\w*)/;
   my $delimeter = qr/\\\h*+\Z/;

   while (1) {
   	my $l = shift @lines;
   	last if !$l;

   	if (!$ncond) {
   		for ($l) {
   			when (m/\A
                  ${h}*+
                  \K
                  \#
                  ${h}*+
                  define
                  ${h}*+
                     $def
                     (?:\(${h}*+(?<args>[^)]*)\))?
                  ${h}*+
                     (?<val>.+?)?
                  \Z\n/px) {
               my $name = $+{def};
   				warn("$name already defined.\n") if $macro_set->exists($name);
               my ($args, $code) = ($+{args}, ${^MATCH});

               if (defined $code && $code =~ m/$delimeter/) {
                  $code .= shift(@lines) while $lines[0] =~ m/$delimeter/;
                  $code .= shift @lines;
               }
               $code = rtrim($code);

               $args = [$args =~ m/[a-zA-Z_]\w*/g] if $args;
   
   				$macro_set->push(C::Macro->new(name => $name, args => $args, code => $code));
   			}
   			when (m/\A${h}*+#${h}*+if(?<no>n)?def${h}++${def}${h}*+\Z/) {
               my $exists = $macro_set->exists($+{def});
               $ncond = (exists $+{no}) ? $exists : !$exists;
   			}
            when (m/\A${h}*+#${h}*+(?<else>el)?if${h}*+(?<cond>.*?)${h}*+\Z/) {
               my $buf = $+{cond};
               my $else = exists $+{'else'};
               $buf =~ s/$Local::C::Transformation::replacement//g;
               if ($buf =~ s/$delimeter//) {
                  while ($lines[0] =~ m/$delimeter/p) {
                     #add str before delimeter
                     $buf .= ${^PREMATCH};
                     shift(@lines);
                  }
                  $buf .= shift(@lines);
               }

               $buf =~ s/$Local::C::Transformation::replacement//g;
               $ncond = ! def_eval($macro_set, $buf);
               $ncond = ! $ncond if $else;
            }
   			when (m/\A${h}*+#${h}*+else/) {
   				$ncond = !$ncond;
   			}
   			when (m/\A${h}*+#${h}*+undef${h}++${def}/) {
               my $name = $+{def};
               if ($macro_set->exists($name)) {
      				$macro_set->delete($name)
               } else {
                  warn("Trying to undefine $name, but it is not defined.\n")
               }
   			}
   			when (m/\A${h}*+#${h}*+endif/) {
   				#nothing to do
   			}
   			default {
               push @preprocessed, $l;
   			}
   		}
   	} else {
   		for ($l) {
   			when (m/\A${h}*+#${h}*+if((n)?def)?/) {
   				++$ncond_rec;
   			}
   			when (m/\A${h}*+#${h}*+else/) {
   				$ncond = !$ncond if $ncond_rec == 0;
   			}
   			when (m/\A${h}*+#${h}*+endif/) {
   				if ($ncond_rec == 0) {
   					$ncond = !$ncond;
   				} else {
                  --$ncond_rec;
               }
   			}
   		}
   	}
   }
   
   #preprocessing done
   join('', @preprocessed)
}

1;
