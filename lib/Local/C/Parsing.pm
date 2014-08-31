package Local::C::Parsing;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use RE::Common qw($varname);
use Local::List::Utils qw(uniq any);
use Local::C::Transformation qw(:RE);

our @EXPORT_OK = qw(parse_structures parse_calls _argname _argname_exists _get_structure_fields _get_structure_wo_field_names);

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
   my @result = ();

   if ($_[0] =~ m/\(${h}*+\*${h}*+($varname)${h}*+\)${h}*+\(/) {
      @result = ($1);
      my ($begin, $end) = ($+[0]+1, rindex($_[0], ')'));

      foreach(split(/,/, substr($_[0], $begin, $end - $begin))) {
         next if m/\A${s}*+\z/;
         my $name = _argname($_);

         push @result, $name if $name
      }

      return @result
   }

   my $name_ex = qr/($varname)(?:\[[^\]]+\]|:\d+)?/;
   my $several = index($_[0], ',');
   if ($several != -1) {
      my $tail = substr($_[0], $several + 1);
      push @result, $1 while ($tail =~ m/($varname)/g);

      $_[0] =~ m/${name_ex}${h}*+,/;
      unshift @result, $1;

      return @result;
   } elsif ($_[0] =~ m/${name_ex}${h}*+\Z/) {
      return $1 ne 'void'? ($1) : (); #just in case
   }

   ()
}

sub _argname
{
   if (index($_[0], '(') != -1) {
      return _argname_exists($_[0])
   } else {
      my @a = $_[0] =~ m/$varname/g;
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

   ()
}

sub _get_structure_fields
{
   my $code = $_[0];
   my ($begin, $end) = (index($code, '{') + 1, rindex($code, '}'));
   $code = substr($code, $begin, $end - $begin);

   my @fields;
   foreach(split(/;/, $code)) {
      next if m/\A${s}*+\z/;

      push @fields, _argname_exists($_)
   }

   \@fields
}

sub _get_structure_wo_field_names
{
   my $code = $_[0];
   my ($begin, $end) = (index($code, '{') + 1, rindex($code, '}'));

   my $repl = '';
   foreach my $line (split(/;/, substr($code, $begin, $end - $begin))) {
      next if $line =~ m/\A${s}*+\z/;

      foreach (_argname_exists($line)) {
         $line =~ s/\b\Q$_\E\b(?=.*+\z)//;
      }

      $repl .= $line
   }

   substr($code, $begin, $end - $begin - 1, $repl);

   $code
}

sub parse_structures
{
   my @s = [$_[0] =~ m/struct${s}++($varname)/g];

   uniq(\@s);

   \@s
}

sub parse_calls
{
   my @calls;

   while (
      $_[0] =~
         m/
            \b(?<fname>$varname)
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

