package C::TypedefSet;
use Moose;

use C::Typedef;
use Local::C::Transformation qw(:RE);
use namespace::autoclean;

use re '/aa';


extends 'C::Set';

has '+set' => (
   isa => 'ArrayRef[C::Typedef]',
);

sub parse_typedef
{
   my $self = shift;
   my %typedefs;

   my $name = qr/(?:[\*\s]+)?(?<name>[a-zA-Z_]\w*)(?:\[[^\]]+\])?/;

   while ($_[0] =~ m/^${h}*+(?:__extension__)?${h}*+\Ktypedef${s}*+
         (?:
            (?:(?:(?:struct|union|enum)${s}*+(?:[a-zA-Z_]\w*)?${s}*+(?<crec>\{(?:(?>[^\{\}]+)|(?&crec))+\}))(?:${s}*+PARSEC_PACKED)?${s}*+($name))
            |
            (?:.*?(?:\($name\)|$name)${s}*+(?<nrec>\((?:(?>[^()]+)|(?&nrec))+\)))
            |
            (?:(?:.*?)${s}*+(?:$name))
         )${s}*+;
      /gmpx) {
      carp("Repeated defenition of typedef $+{name}") if (exists $typedefs{$+{name}});
      $typedefs{$+{name}} = ${^MATCH}
   }

   return $self->new(set => [ map { C::Typedef->new(name => $_, code => $typedefs{$_}) } keys %typedefs ]);
}


__PACKAGE__->meta->make_immutable;

1;
