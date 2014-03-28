package C::Set;
use namespace::autoclean;
use Moose;

has 'set' => (
   is => 'rw',
   isa => 'ArrayRef',
   traits => ['Array'],
   required => 1,
   handles => {
      push            => 'push',
      map             => 'map',
      get_from_index  => 'get'
   }
);


has 'ids' => (
   is => 'ro',
   isa => 'ArrayRef[ArrayRef[Str]]',
   lazy => 1,
   builder => '_build_ids'
);

has 'tags' => (
   is => 'ro',
   isa => 'ArrayRef[ArrayRef[Str]]',
   lazy => 1,
   builder => '_build_tags'
);

sub _build_ids
{
   [ $_[0]->map( sub { $_->get_code_ids } ) ];
}

sub _build_tags
{
   [ $_[0]->map( sub { $_->get_code_tags } ) ];
}


__PACKAGE__->meta->make_immutable;

1;
