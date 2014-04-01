package C::GlobalSet;
use namespace::autoclean;
use Moose;

use re '/aa';
use Local::C::Transformation qw(:RE);

use Carp;

use C::Global;

extends 'C::Set';

has '+set' => (
   isa => 'ArrayRef[C::Global]'
);


sub parse_global
{
   my %globals;

   while ($_[1] =~ m/extern${s}++([^;}{]+?)(?<name>[a-zA-Z_]\w*)${s}*+;/gp) {
      $globals{$+{name}} = ${^MATCH}
   }

   return $_[0]->new(set => [ map {C::Global->new(name => $_, code => $globals{$_})} keys %globals ]);
}

__PACKAGE__->meta->make_immutable;

1;
