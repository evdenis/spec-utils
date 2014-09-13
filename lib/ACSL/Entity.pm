package ACSL::Entity;
use Moose;

use Moose::Util::TypeConstraints;
use Local::List::Utils qw(difference);
use C::Keywords qw(prepare_tags);
use namespace::autoclean;

use feature qw(state);
use re '/aa';


has 'names' => (
   is => 'rw',
   isa => 'ArrayRef[Str]',
   required => 1
);

has 'specification' => (
   is => 'ro',
   isa => 'Str',
   required => 1
);

sub to_string
{
   $_[0]->specification
}

sub get_code_ids
{
   [ $_[0]->names ]
}

sub get_code_tags
{
   prepare_tags($_[0]->code, $_[0]->get_code_ids())
}


__PACKAGE__->meta->make_immutable;

1;
