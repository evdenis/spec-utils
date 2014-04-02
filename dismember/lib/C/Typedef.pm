package C::Typedef;
use Moose;
use namespace::autoclean;

extends 'C::Entity';

__PACKAGE__->meta->make_immutable;

1;
