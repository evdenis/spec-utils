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
   my @globals;
   my $name   = qr/(?<name>${varname})/;
   my $sbody  = qr/(?<sbody>\{(?:(?>[^\{\}]+)|(?&sbody))*\})/;
   my $init   = qr/(?:${s}*+(?:\[[^\]]*+\]))?(?:${s}*+=${s}*+(?:$sbody|[^;]++))?/;
   my $ptr    = qr/(\*|${s}++|const)*+/;
   my $type   = qr/(?<type>\b(?!PARSEC_PACKED)${varname}\b${ptr})/;

   while (${$_[0]} =~ m/(?:(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\})))(*SKIP)(*FAIL)
                        |
                        (?>
                           (?:(?:const|volatile|register|static|extern|(?<td>typedef))${s}++)*+
                           (?>
                              (?>(?<type>(?:(?:unsigned|(?:__)?signed(?:__)?)${s}*+)?(?:char|short|int|long|long${s}++long)${ptr})(*SKIP)${name}${init})
                              |
                              (?>(?<type>(?>float|double|size_t|u?int(8|16|32|64)_t|uchar\b|ushort\b|uint\b|ulong\b|spinlock_t)${ptr})(*SKIP)${name}${init})
                              |
                              (?>enum(*SKIP)${s}++(?<type>${varname}${ptr})${name}${init})
                              |
                              (?>
                                 (?>struct|union)(*SKIP)${s}++${type}${name}${init}
                                 |
                                 (?<type>DEFINE_SPINLOCK|DEFINE_RWLOCK)${s}*+\(${s}*+${name}${s}*+\)
                              )
                              |
                              (?:${type}${name}${init})
                           )
                        )(*SKIP)
                        ${s}*+;
                     /gxp) {
      push @globals, {name => $+{name}, code => ${^MATCH}, type => $+{type}}
         if exists $+{name} && ! exists $+{td}
   }

   return $self->new(set => [ map {C::Global->new(name => $_->{name}, code => $_->{code}, type => $_->{type}, area => $area)} @globals ]);
}

__PACKAGE__->meta->make_immutable;

1;
