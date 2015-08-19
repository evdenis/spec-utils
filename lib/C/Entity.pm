package C::Entity;
use Moose;

use Moose::Util::TypeConstraints;
use Local::List::Util qw(difference);
use C::Keywords qw(prepare_tags);
use namespace::autoclean;

use feature qw(state);
use re '/aa';


has 'id' => (
   is => 'ro',
   isa => 'Int',
   lazy => 1,
   required => 1,
   builder => '_compose_id',
   init_arg => undef
);

# zero is a special value
# id should be always true
our $_NEXT_ID = 1;

sub _compose_id
{
   $_NEXT_ID++
}


has 'name' => (
   is => 'rw',
   isa => 'Str',
   required => 1
);

has 'code' => (
   is => 'rw',
   isa => 'Str',
   required => 1
);

has 'area' => (
   is => 'ro',
   isa => enum([qw(kernel module unknown)]),
   required => 1
);

sub to_string
{
   $_[0]->code
}

sub get_code_ids
{
   [ $_[0]->name ]
}

sub get_code_tags
{
   prepare_tags($_[0]->code, $_[0]->get_code_ids())
}


__PACKAGE__->meta->make_immutable;

1;
