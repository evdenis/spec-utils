package ACSL::Common;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use RE::Common qw($acsl_varname $acsl_contract $acsl_invariant $acsl_assert);
use C::Keywords qw(%c_keywords_filter not_special_label);

our @EXPORT_OK = qw(is_acsl_spec
  is_contract
  is_invariant
  is_assert
  prepare_tags);

sub is_acsl_spec ($)
{
   $_[0] =~ m!^\s*+(?:/\*\@|//\@)!;
}

my @acsl_keywords = qw(
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
  Pre
  Here
  Old
  Post
  LoopEntry
  LoopCurrent
);

my %acsl_keywords_filter = map {$_ => undef} @acsl_keywords;

sub is_acsl_keyword
{
   my $r = 0;
   if (index($_[0], '\\') == 0) {
      $r = 1;
   } elsif (exists $acsl_keywords_filter{$_[0]}) {
      $r = 1;
   }

   $r;
}

sub is_contract
{
   $_[0] =~ $acsl_contract;
}

sub is_invariant
{
   $_[0] =~ $acsl_invariant;
}

sub is_assert
{
   $_[0] =~ $acsl_assert;
}

sub prepare_tags
{
   my %filter = map {$_ => undef} @{$_[1]};
   my $token = qr/($acsl_varname)\b/;    # don't append \b to the beginning

   my $code = substr($_[0], 3);

   # remove strings
   $code =~ s/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'//g;
   # remove behaviors with labels
   $code =~ s/behavior\s+\w+://g;
   # remove comments; nested multiline are impossible
   $code =~ s!//.*!!g;

   my @tokens;
   while ($code =~ m/$token/g) {
      if (not_special_label($1)) {
         push @tokens, $1;
      } else {
         my $special = $1;

         push @tokens, [$special, $1]
           if $code =~ m/\G\s*+$token/gc;
      }
   }

   my @tags;
   my %uniq;
   foreach (@tokens) {
      my $id;
      if (ref $_ eq 'ARRAY') {
         $id = $_->[0] . ' ' . $_->[1];
      } else {
         next if exists $c_keywords_filter{$_} || is_acsl_keyword($_);
         $id = $_;
      }

      push @tags, $_
        if !$uniq{$id}++ && !exists $filter{$id};
   }

   \@tags;
}

1;
