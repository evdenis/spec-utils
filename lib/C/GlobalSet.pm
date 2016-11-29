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

my %type_alias = (
    DEFINE_SPINLOCK => 'spinlock_t',
    DEFINE_RWLOCK   => 'rwlock_t',
    LIST_HEAD       => 'struct list_head',
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
   my $type   = qr/\b(?!PARSEC_PACKED)${varname}\b${ptr}/;

   while (${$_[0]} =~ m/(?:(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\})))(*SKIP)(*FAIL)
                        |
                        (?>
                           (?<modifiers>(?:(?:const|volatile|register|static|extern|(?<td>typedef))${s}++)*+)
                           (?>
                              (?>(?<type>(?:(?:unsigned|(?:__)?signed(?:__)?)${s}*+)?(?:char|short|int|long|long${s}++long)(?:\h+(?:volatile|__jiffy_data))*${ptr})(*SKIP)${name}${init})
                              |
                              (?>(?<type>(?>float|double|size_t|u?int(?:8|16|32|64)_t|u(?:8|16|32|64)|uchar\b|ushort\b|uint\b|ulong\b|spinlock_t)(?:\h+__jiffy_data)?${ptr})(*SKIP)${name}${init})
                              |
                              (?>(?<type>enum(*SKIP)${s}++${varname}${ptr})${name}${init})
                              |
                              (?>
                                 (?<type>(?>struct|union)(*SKIP)${s}++${type})${name}${init}
                                 |
                                 (?<type>DEFINE_SPINLOCK|DEFINE_RWLOCK|LIST_HEAD)${s}*+\(${s}*+${name}${s}*+\)
                                 |
                                 (?<type>DEFINE_DEBUGFS_ATTRIBUTE)${s}*+\(${s}*+${name}${s}*+,[^)]++\)
                                 |
                                 (?<type>FULL_PROXY_FUNC)${s}*+\(${s}*+${name}${s}*+(?:[^(]++\([^)]++\)){2}${s}*+\)
                              )
                              |
                              (?:(?<type>${type})${name}${init})
                           )
                        )(*SKIP)
                        ${s}*+;
                     /gxp) {
         if (exists $+{name} && ! exists $+{td}) {
            my $name     = $+{name};
            my $code     = ${^MATCH};
            my $type     = $+{type};
            my $modifier = $+{modifiers};

            if ($type eq 'FULL_PROXY_FUNC') {
               $name = 'full_proxy_' . $name
            }

            if (exists $type_alias{$type}) {
               $type = $type_alias{$type}
            }

            push @globals, {
               name     => $name,
               code     => $code,
               type     => $type,
               modifier => $modifier
            };
         }
   }

   return $self->new(set => [ map {C::Global->new(name => $_->{name}, code => $_->{code}, type => $_->{type}, modifier => $_->{modifier}, area => $area)} @globals ]);
}

__PACKAGE__->meta->make_immutable;

1;
