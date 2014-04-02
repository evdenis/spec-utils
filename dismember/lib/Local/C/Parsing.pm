package Local::C::Parsing;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use Local::List::Utils qw(uniq any);
use Local::C::Transformation qw(:RE);

our @EXPORT_OK = qw(parse_structures parse_calls _argname _argname_exists);

our @keywords = qw(
auto
break
case
char
const
continue
default
do
double
else
enum
extern
float
for
goto
if
inline
int
long
register
restrict
return
short
signed
sizeof
static
struct
switch
typedef
union
unsigned
void
volatile
while
_Alignas
_Alignof
_Atomic
_Bool
_Complex
_Generic
_Imaginary
_Noreturn
_Static_assert
_Thread_local
);

#additional filtration keywords. kernel related
push @keywords, qw(
typeof
__attribute__
__typeof__
asm
__section__
section
alias
aligned
);

#__builtin_.+


sub _argname_exists
{
   if ($_[0] =~ m/(?|([a-zA-Z_]\w*+)(?:\[[^\]]+\]|:\d+)?${h}*+\Z|\(${h}*+\*${h}*+([a-zA-Z_]\w*+)${h}*+\)${h}*+\()/) {
      return $1 ne 'void' ? $1 : undef; #just in case
   }
}

sub _argname
{
   if (index($_[0], '(') != -1) {
      if ($_[0] =~ m/\(${h}*+\*${h}*+([a-zA-Z_]\w*+)${h}*+\)${h}*+\(/) {
         return $1
      }
   } else {
      my @a = $_[0] =~ m/[a-zA-Z_]\w*+/g;
      my $i  = 1;
      my $us = 0;
      my $l  = 0;


      foreach (@a) {
         if ($l) {
            ++$i if $_ eq 'long';
            $l = 0;
         }

         if ($us) {
            ++$i if  $_ eq 'char'  ||
                     $_ eq 'short' ||
                     $_ eq 'int'   ||
                     $_ eq 'long';
           $us = 0;
         }


         ++$i  if $_ eq 'struct'   ||
                  $_ eq 'union'    ||
                  $_ eq 'enum'     ||
                  $_ eq 'const'    ||
                  $_ eq 'volatile';

         $us = 1 if $_ eq 'signed' || $_ eq 'unsigned';
         $l  = 1 if $_ eq 'long';
      }

      ++$i if $us;
      ++$i if $l;

      return $a[$#a] if @a > $i;
   }

   undef
}

sub parse_structures
{
   my @s = [$_[0] =~ m/struct${s}++([a-zA-Z_]\w*+)/g];

   uniq(\@s);

   \@s
}

sub parse_calls
{
   my @calls;

   while (
      $_[0] =~
         m/
            \b(?<fname>[a-zA-Z_]\w*+)
            ${s}*+
            (?<fargs>\((?:(?>[^\(\)]+)|(?&fargs))*\))
            (?!${s}*+(?:\{|\()) # исключает функции которые ни разу не вызываются
         /gx
   ) {
      # Просматриваем ещё раз аргументы вызова прошлой функции.
      # Там могут быть ещё вызовы.
      # -1 - первая скобка после имени не учитывается.
      my $offset = pos($_[0]) - (length($+{fargs}) - 1);

      my $call = $+{fname};
      push @calls, $call;

      pos($_[0]) = $offset;
   }

   #filter
   @calls = grep { ! any($_, \@keywords) } @calls;
   uniq(\@calls);

   \@calls
}

1;

