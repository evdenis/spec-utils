package C::Acslcomment;
use Moose;

use Moose::Util::TypeConstraints;
use Local::List::Util qw(difference);
use ACSL::Common qw(prepare_tags);
use RE::Common qw($varname);
use namespace::autoclean;
use C::GlobalSet;
use C::EnumSet;

use feature qw(state);
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

   my @ids = $code =~ m/(?|
                           (?:predicate\s++($varname))|
                           (?:inductive\s++($varname))|
                           (?:type\s++($varname))|
                           (?:logic[\wℤ𝔹\s\*]+\b($varname)\s*+[(={])
                        )/gx;

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
