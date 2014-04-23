package C::Structure;
use Moose;

use Moose::Util::TypeConstraints;
use Local::C::Parsing qw(_get_structure_fields);
use Local::C::Transformation qw(:RE);
use C::Keywords qw(prepare_tags);
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';



has 'type' => (
   is => 'ro',
   isa => enum([qw(struct union)]),
   required => 1
);


sub get_code_tags
{
   my $code = $_[0]->code;

   my $filter = [$_[0]->type . ' ' . $_[0]->name]; #instead if get_code_ids
   push @$filter, @{ _get_structure_fields($code) };

   prepare_tags($code, $filter)
}


__PACKAGE__->meta->make_immutable;

1;
