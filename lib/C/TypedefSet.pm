package C::TypedefSet;
use Moose;

use RE::Common qw($varname);
use C::Typedef;
use C::Util::Transformation qw(:RE norm);
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with 'C::Parse';

has '+set' => (isa => 'ArrayRef[C::Typedef]',);

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my %typedefs;

   my $name = qr/(?:[\*\s]+)?(?<name>\b$varname)\b${s}*+(?:\[[^\]]*\])?/;

   while (
      ${$_[0]} =~ m/^${h}*+(?:__extension__)?${h}*+\Ktypedef${s}*+
         (?:
            (?:(?:(?:struct|union|enum)${s}*+(?:$varname)?${s}*+(?<crec>\{(?:(?>[^\{\}]+)|(?&crec))+\}))(?:${s}*+PARSEC_PACKED)?${s}*+($name))
            |
            (?:.*?(?:\($name\)|$name)${s}*+(?<nrec>\((?:(?>[^()]+)|(?&nrec))+\)))
            |
            (?:.*?${s}*+$name)
         )${s}*+;
      /gmpx
     )
   {
      my $name = $+{name};
      my $code = ${^MATCH};

      if (exists $typedefs{$name} && (norm($typedefs{$name}) ne norm($code))) {
         warn "Redefinition of typedef $name\n";
      }
      $typedefs{$name} = $code;
   }

   return $self->new(set => [map {C::Typedef->new(name => $_, code => $typedefs{$_}, area => $area)} keys %typedefs]);
}

__PACKAGE__->meta->make_immutable;

1;
