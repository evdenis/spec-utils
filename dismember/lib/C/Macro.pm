package C::Macro;
use namespace::autoclean;
use Moose;

use Local::C::Parse qw(@keywords);
use Local::List::Utils qw(difference);

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
      $code =~ m/$name(?:\(\h*+[^)]*\))?\s*+/;

      return substr($code, $+[0]);
   } else {
      return undef;
   }
}


sub get_code_tags
{
   my @list = ($_[0]->substitution =~ m/\b[a-zA-Z_]\w*\b/g);

   my $filter = $_[0]->get_code_ids();
   push @$filter, @keywords;
   push @$filter, @{ $_[0]->args } if $_[0]->args;

   [ difference(\@list, $filter) ]
}


__PACKAGE__->meta->make_immutable;

1;
