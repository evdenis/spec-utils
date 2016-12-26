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
    DEFINE_SPINLOCK         => 'spinlock_t',
    DEFINE_MUTEX            => 'struct mutex',
    DEFINE_RWLOCK           => 'rwlock_t',
    DECLARE_WAIT_QUEUE_HEAD => 'wait_queue_head_t',
    DECLARE_WORK            => 'struct work_struct',
    DECLARE_DELAYED_WORK    => 'struct delayed_work',
    DECLARE_DEFERRABLE_WORK => 'struct delayed_work',
    LIST_HEAD               => 'struct list_head',
);

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my @globals;
   my $name           = qr/(?<name>${varname})/;
   my $sbody          = qr/(?<sbody>\{(?:(?>[^\{\}]+)|(?&sbody))*\})/;
   my $fargs          = qr/(?<fargs>\((?:(?>[^\(\)]+)|(?&fargs))*\))/;
   my $array          = qr/(?:${s}*+(?:\[[^\]]*+\]\h*+)+)/;
   my $decl           = qr/(?:${s}*+${sbody})/;
   my $init           = qr/(?:${s}*+=${s}*+(?:${sbody}|[^;]*+))/; # requires strings to be previously hided
   my $ptr            = qr/(\*|${s}++|const)*+/;
   my $standard_type  = qr/(?>(?:(?:unsigned|(?:__)?signed(?:__)?)${s}++)?(?:char|short|int|long|float|double|long${s}++long))/;
   my $common_typedef = qr/(?>size_t|u?int(?:8|16|32|64)_t|u(?:8|16|32|64)|uchar\b|ushort\b|uint\b|ulong\b|spinlock_t)/;
   my $simple_type    = qr/(?>(?:$standard_type|$common_typedef)(?:\h+(?:volatile|__jiffy_data))*${s}*+${ptr})/;
   #my $mandatory_init = qr/${array}?${init}/;
   my $optional_init  = qr/(?:\h*+__initdata)?${init}?/;
   my $optional_ainit = qr/${array}?${optional_init}/;
   my $type           = qr/\b(?!PARSEC_PACKED)${varname}\b${ptr}/;
   my $complex_type   = qr/(?>struct|union|enum)(*SKIP)${s}++${type}/;

   while (${$_[0]} =~ m/(?:${sbody})(*SKIP)(*FAIL)
                        |
                        (?>
                           (?<modifiers>(?:(?:const|volatile|register|static|extern|(?<td>typedef))${s}++)*+)
                           (?>
                              (?<typeof>__typeof__${s}*+\(${s}*+)?+
                              (?<type>${simple_type}|${complex_type})
                                      ${decl}?(?(<typeof>)\))${s}*+(?:__packed(*SKIP)(*FAIL)|${name})(?:${s}*+__initdata)?${optional_ainit}
                              |
                              (?<type>(?>${simple_type}|${complex_type})\(${s}*+\*${s}*+${name}${array}?${s}*+\)${s}*+${fargs})(*SKIP)${optional_init}
                              |
                              (?<type>\b(?:DEFINE_(?:SPINLOCK|RWLOCK|MUTEX)|LIST_HEAD)|DECLARE_WAIT_QUEUE_HEAD)${s}*+\(${s}*+${name}${s}*+\)
                              |
                              (?<type>\bDEFINE_DEBUGFS_ATTRIBUTE)${s}*+\(${s}*+${name}${s}*+,[^)]++\)
                              |
                              (?<type>\bDECLARE_(?:DELAYED_|DEFERRABLE_)?WORK)${s}*+\(${s}*+${name}${s}*+,[^)]++\)
                              |
                              (?<type>\bFULL_PROXY_FUNC)${s}*+\(${s}*+${name}${s}*+(?:[^(]++\([^)]++\)){2}${s}*+\)
                              |
                              (?:\bMODULE_LICENSE\b${s}*+\([^)]++\))
                              |
                              (?:\b(?:(?<special_declare>DECLARE)|DEFINE)_PER_CPU\b${s}*+\(${s}*+(?<type>[^,]++),${s}*+${name}${s}*+\))
                              |
                              (?<type>${type})${name}${optional_ainit}
                           )
                        )(*SKIP)
                        ${s}*+;
                        |
                        (?<type>\bFAT_IOCTL_FILLDIR_FUNC)${s}*+\(${s}*+${name}${s}*+,[^)]++\)
                        |
                        (?:\bEXPORT_SYMBOL(?:_GPL)?\b${s}*+\([^)]++\)${s}*+;)
                        |
                        (?:\bmodule_(?:init|exit)\b${s}*+\([^)]++\))
                        |
                        (?:\b__setup\b${s}*+\([^)]++\)${s}*+;)
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
