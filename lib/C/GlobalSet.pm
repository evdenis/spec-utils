package C::GlobalSet;
use Moose;

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
    DEFINE_MUTEX    => 'struct mutex',
    DEFINE_RWLOCK   => 'rwlock_t',
    LIST_HEAD       => 'struct list_head',
);

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my @globals;
   my $name           = qr/(?<name>${varname})/;
   my $sbody          = qr/(?<sbody>\{(?:(?>[^\{\}]+)|(?&sbody))*\})/;
   my $array          = qr/(?:${s}*+(?:\[[^\]]*+\]))/;
   my $decl           = qr/(?:${s}*+${sbody})/;
   my $init           = qr/(?:${s}*+=${s}*+(?:${sbody}|"[^\n]*(?="\h*;)"|[^;]++))/;
   my $standard_type  = qr/(?>(?:(?:unsigned|(?:__)?signed(?:__)?)${s}++)?(?:char|short|int|long|float|double|long${s}++long))/;
   my $common_typedef = qr/(?>size_t|u?int(?:8|16|32|64)_t|u(?:8|16|32|64)|uchar\b|ushort\b|uint\b|ulong\b|spinlock_t)/;
   my $simple_type    = qr/(?:$standard_type|$common_typedef)/;
   #my $mandatory_init = qr/${array}?${init}/;
   my $optional_init  = qr/${array}?${init}?/;
   my $ptr            = qr/(\*|${s}++|const)*+/;
   my $type           = qr/\b(?!PARSEC_PACKED)${varname}\b${ptr}/;

   while (${$_[0]} =~ m/(?:(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\})))(*SKIP)(*FAIL)
                        |
                        (?>
                           (?<modifiers>(?:(?:const|volatile|register|static|extern|(?<td>typedef))${s}++)*+)
                           (?>
                              (?>(?<type>${simple_type}(?:\h+(?:volatile|__jiffy_data))*${s}++${ptr})(*SKIP)${name}(?:${s}*+__initdata${s}*+)?${optional_init})
                              |
                              (?>(?<type>enum(*SKIP)${s}++${varname}${ptr})${name}${optional_init})
                              |
                              (?>__typeof__${s}*+\(${s}*+(?<type>${simple_type}|(?>struct|union)(*SKIP)${s}++${type})\)${s}*+${name}${optional_init})
                              |
                              (?>
                                 (?<type>(?>struct|union)(*SKIP)${s}++${type})${decl}?${s}*+(?:__packed(*SKIP)(*FAIL)|${name})${optional_init}
                                 |
                                 (?<type>\bDEFINE_(?:SPINLOCK|RWLOCK|MUTEX)|LIST_HEAD)${s}*+\(${s}*+${name}${s}*+\)
                                 |
                                 (?<type>\bDEFINE_DEBUGFS_ATTRIBUTE)${s}*+\(${s}*+${name}${s}*+,[^)]++\)
                                 |
                                 (?<type>\bFULL_PROXY_FUNC)${s}*+\(${s}*+${name}${s}*+(?:[^(]++\([^)]++\)){2}${s}*+\)
                                 |
                                 (?:\bMODULE_LICENSE\b${s}*+\([^)]++\))
                                 |
                                 (?:\b(?:(?<special_declare>DECLARE)|DEFINE)_PER_CPU\b${s}*+\(${s}*+(?<type>[^,]++),${s}*+${name}${s}*+\))
                                 |
                                 (?:\b(?<special_declare>DECLARE)_WORK\b${s}*+\(${s}*+${name}${s}*+,[^)]++\))
                              )
                              |
                              (?:(?<type>${type})${name}${optional_init})
                           )
                        )(*SKIP)
                        ${s}*+;
                        |
                        (?<type>\bFAT_IOCTL_FILLDIR_FUNC)${s}*+\(${s}*+${name}${s}*+,[^)]++\)
                        |
                        (?:\bEXPORT_SYMBOL(?:_GPL)?\b${s}*+\([^)]++\)${s}*+;)
                        |
                        (?:\bmodule_(?:init|exit)\b${s}*+\([^)]++\))
                     /gxp) {
         if (!exists $+{td}) {
            my $mname     = $+{name} // '';
            my $mcode     = ${^MATCH};
            my $mtype     = $+{type};
            my $mmodifier = $+{modifiers} || undef;
            my $special_declare = $+{special_declare};

            unless ($mtype) {
               $mtype = "--MODULE--"
            } else {
               if ($mtype eq 'FULL_PROXY_FUNC') {
                  $mname = 'full_proxy_' . $mname
               }
               if (exists $type_alias{$mtype}) {
                  $mtype = $type_alias{$mtype}
               }
            }

            if ($special_declare) {
               $mmodifier = 'extern ' . ($mmodifier // '');
            }

            push @globals, {
               name     => $mname,
               code     => $mcode,
               type     => $mtype,
               modifier => $mmodifier
            };
         }
   }

   return $self->new(set => [
           map { C::Global->new(
               name     => $_->{name},
               code     => $_->{code},
               type     => $_->{type},
               modifier => $_->{modifier},
               area     => $area)
           } @globals
       ]
   );
}

__PACKAGE__->meta->make_immutable;

1;
