package C::Macro;
use Moose;

use C::Keywords qw(prepare_tags);
use Local::List::Utils qw(difference);
use namespace::autoclean;

extends 'C::Entity';

has 'args' => (
   is => 'ro',
   isa => 'Maybe[ArrayRef[Str]]',
   predicate => 'has_args'
);

has 'substitution' => (
   is => 'ro',
   isa => 'Maybe[Str]',
   lazy => 1,
   builder => '_build_substitution'
);

sub _build_substitution
{
   my $self = shift;
   my $code = $self->code;
   my $name = $self->name;

   if ($code) {
      $code =~ s/\\\h*+$//mg;
      $code =~ m/\b$name\b(?:\(\h*+[^)]*+\))?\s*+/;

      return substr($code, $+[0]);
   } else {
      return undef;
   }
}


sub get_code_tags
{
   my $filter = $_[0]->get_code_ids();
   push @$filter, @{ $_[0]->args } if $_[0]->args; #struct arg case ?

   prepare_tags($_[0]->substitution, $filter)
}


__PACKAGE__->meta->make_immutable;

1;
