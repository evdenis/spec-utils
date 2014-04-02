package C::GlobalSet;
use Moose;

use Carp;

use C::Global;
use Local::C::Transformation qw(:RE);
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with    'C::Parse';

has '+set' => (
   isa => 'ArrayRef[C::Global]'
);


sub parse
{
   my $self = shift;
   my $area = $_[1];
   my %globals;

   while ($_[0] =~ m/extern${s}++([^;}{]+?)(?<name>[a-zA-Z_]\w*)${s}*+;/gp) {
      $globals{$+{name}} = ${^MATCH}
   }

   return $self->new(set => [ map {C::Global->new(name => $_, code => $globals{$_}, area => $area)} keys %globals ]);
}

__PACKAGE__->meta->make_immutable;

1;
