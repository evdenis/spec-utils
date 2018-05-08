package C::Set;
use Moose;
use namespace::autoclean;

has 'set' => (
   is       => 'rw',
   isa      => 'ArrayRef',
   traits   => ['Array'],
   required => 1,
   handles  => {
      push           => 'push',
      map            => 'map',
      get_from_index => 'get'
   }
);

sub ids
{
   [$_[0]->map(sub {$_->get_code_ids})]
}

sub tags
{
   [$_[0]->map(sub {$_->get_code_tags})]
}

__PACKAGE__->meta->make_immutable;

1;
