package Local::C::Parse;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use Local::List::Utils qw(uniq any);

our @EXPORT_OK = qw(parse_structures parse_calls @keywords);

our @keywords = qw/
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
int
long
register
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
typeof
defined
__attribute__
__typeof__
asm
__section__
section
alias
aligned
/;

#__builtin_.+


sub parse_structures
{
   my @s = [$_[0] =~ m/struct\s+([a-zA-Z_]\w*)/g];

   uniq(\@s);

   \@s
}

sub parse_calls
{
   my @calls;

   while (
      $_[0] =~
         m/
            \b(?<fname>[a-zA-Z_]\w*)
            \s*
            (?<fargs>\((?:(?>[^\(\)]+)|(?&fargs))*\))
            (?!\s*(?:\{|\()) # исключает функции которые ни разу не вызываются
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

