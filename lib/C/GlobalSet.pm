package C::GlobalSet;
use Moose;

use Carp;

use RE::Common qw($varname);
use C::Global;
use C::Util::Transformation qw(:RE);
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
   my $name = qr/(?<name>${varname})/;

   while (${$_[0]} =~ m/
                        (?:
                           (?:extern${s}++([^;}{]+?)${name}\b${s}*+(?:\[[^\]]*+\])?${s}*+)
                           |
                           (?:
                              static${s}++
                              (?:
                                 struct${s}++${varname}${s}++${name}${s}*+=${s}*+(?<sbody>\{(?:(?>[^\{\}]+)|(?&sbody))*\})
                                 |
                                 DEFINE_SPINLOCK${s}*+\(${s}*+${name}${s}*+\)
                              )
                           )
                        )
                        ${s}*+;
                     /gxp) {
      $globals{$+{name}} = ${^MATCH}
   }

   return $self->new(set => [ map {C::Global->new(name => $_, code => $globals{$_}, area => $area)} keys %globals ]);
}

__PACKAGE__->meta->make_immutable;

1;
