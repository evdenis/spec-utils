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
   isa => 'ArrayRef[Maybe[Str]]',
   lazy => 1,
   builder => '_build_ids'
);

has 'tags' => (
   is => 'ro',
   isa => 'ArrayRef[Maybe[Str]]',
   lazy => 1,
   builder => '_build_tags'
);

sub _build_ids
{
   [ $_[0]->map( sub { '\b(?:' . join('|', @{ $_->get_code_ids }) . ')\b' } ) ]
}

sub _build_tags
{
   [ $_[0]->map( sub {  my @t = @{ $_->get_code_tags };
                        if (@t) {
                           join(' ', @t)
                        } else {
                           undef
                        }
                     } ) ]
}


__PACKAGE__->meta->make_immutable;

1;
