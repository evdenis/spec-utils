package ACSL::Common;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use Local::List::Utils qw(any);

our @EXPORT_OK = qw(is_acsl_spec);

sub is_acsl_spec ($)
{
   $_[0] =~ m!^\s*+(?:/\*\@|//\@)!
}

my @keywords = qw/
char
short
int
long
signed
unsigned
integer
real
float
double
boolean
struct
sizeof
type
lemma
predicate
logic
ensures
requires
terminates
decreases
for
assigns
reads
writes
volatile
assumes
assert
behavior
behaviors
complete
disjoint
inductive
case
loop
invariant
variant
ghost
else
axiomatic
axiom
allocates
frees
set
exits
breaks
continues
returns
true
false
weak
strong
global
module
open
/;
#Pre
#Here
#Old
#Post
#LoopEntry
#LoopCurrent

sub is_acsl_keyword
{
   my $r = 0;
   if (index($_[0], '/') == 0) {
      $r = 1
   } elsif (any($_[0], \@keywords)) {
      $r = 1
   }

   $r
}


1;
