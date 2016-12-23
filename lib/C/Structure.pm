package C::Structure;
use Moose;

use Moose::Util::TypeConstraints;
use C::Util::Parsing qw(_get_structure_wo_field_names);
use C::Util::Transformation qw(:RE);
use C::Keywords qw(prepare_tags);
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';


has 'type' => (
   is => 'ro',
   isa => enum([qw(struct union)]),
   required => 1
);

around BUILDARGS => sub {
   my $orig = shift;
   my $class = shift;
   my $opts = ( ref $_[1] eq 'HASH' ) ? shift : { @_ };

   $opts->{code} =~ s/}\s++;\z/};/;

   $class->$orig($opts)
};

sub get_code_tags
{
   my $code = $_[0]->code;

   my $filter = [$_[0]->type . ' ' . $_[0]->name]; #instead if get_code_ids
   $code = _get_structure_wo_field_names($code);

   prepare_tags($code, $filter)
}

sub to_string
{
   $_[0]->code
}

__PACKAGE__->meta->make_immutable;

1;
