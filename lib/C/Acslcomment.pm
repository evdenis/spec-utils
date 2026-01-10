package C::Acslcomment;
use Moose;
use utf8::all;

use Moose::Util::TypeConstraints;
use ACSL::Common qw(prepare_tags);
use RE::Common qw($varname);
use namespace::autoclean;
use C::GlobalSet;
use C::EnumSet;

use re '/aa';

extends 'C::Entity';

has 'replacement_id' => (
   is       => 'ro',
   isa      => 'Int',
   required => 1
);

has 'get_code_ids' => (
   is       => 'ro',
   isa      => 'ArrayRef[Str]',
   lazy     => 1,
   builder  => '_build_code_ids',
   init_arg => undef
);

has 'function_spec' => (
   isa      => 'Int',
   is       => 'rw',
   default  => 0,
   init_arg => undef
);

has 'is_ghost' => (
   is       => 'ro',
   isa      => 'Bool',
   lazy     => 1,
   builder  => '_build_is_ghost',
   init_arg => undef
);

has 'is_axiomatic' => (
   is       => 'ro',
   isa      => 'Bool',
   lazy     => 1,
   builder  => '_build_is_axiomatic',
   init_arg => undef
);

has 'is_global' => (
   is       => 'ro',
   isa      => 'Bool',
   lazy     => 1,
   builder  => '_build_is_global',
   init_arg => undef
);

has 'number_of_lines' => (
   isa      => 'Int',
   is       => 'ro',
   lazy     => 1,
   builder  => '_count_lines',
   init_arg => undef
);

sub _build_code_ids
{
   #logic
   #predicates
   #types
   my $code = substr($_[0]->code, 3);
   #remove oneline comments; nested multile are not possible
   $code =~ s!//.*!!g;

   my @ids = $code =~ m/\b(?:predicate|inductive|type|logic[\wℤ𝔹\s\*\\<>]+)\s*+\b($varname)\s*+[(={]/g;

   if ((my $i = index($code, 'ghost')) != -1) {
      $i += 5;
      my $si = index($code, ';', $i);
      $code = substr($code, $i, ($si - $i) + 1);
      push @ids, C::EnumSet->parse(\$code, 'unknown')->map(sub {@{$_->get_code_ids}});
      push @ids, C::GlobalSet->parse(\$code, 'unknown')->map(sub {@{$_->get_code_ids}});
   }

   \@ids;
}

sub _count_lines
{
   scalar $_[0]->code =~ tr/\n// + 1;
}

sub _build_is_ghost
{
   # first word is ghost
   return ($_[0]->code =~ m/\w++/p && ${^MATCH} eq 'ghost');
}

sub _build_is_axiomatic
{
   # first word is axiomatic
   return ($_[0]->code =~ m/\w++/p && ${^MATCH} eq 'axiomatic');
}

sub _build_is_global
{
   return $_[0]->is_axiomatic && $_[0]->code =~ m/\blemma\b/;
}

sub get_code_tags
{
   prepare_tags($_[0]->code, $_[0]->get_code_ids());
}

sub to_string
{
   if ($_[0]->function_spec) {
      undef;
   } else {
      $_[0]->code;
   }
}

__PACKAGE__->meta->make_immutable;

1;
