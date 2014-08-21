package C::TypedefSet;
use Moose;

use C::Typedef;
use Local::C::Transformation qw(:RE);
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with    'C::Parse';

has '+set' => (
   isa => 'ArrayRef[C::Typedef]',
);

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my $set = $self->new(set => []);
   my %typedefs;

   my $name = qr/(?:[\*\s]+)?(?<name>[a-zA-Z_]\w*+)\b${s}*+(?:\[[^\]]+\])?/;

   while (${$_[0]} =~ m/^${h}*+(?:__extension__)?${h}*+\Ktypedef${s}*+
         (?:
            (?:(?:(?:struct|union|enum)${s}*+(?:[a-zA-Z_]\w*)?${s}*+(?<crec>\{(?:(?>[^\{\}]+)|(?&crec))+\}))(?:${s}*+PARSEC_PACKED)?${s}*+($name))
            |
            (?:.*?(?:\($name\)|$name)${s}*+(?<nrec>\((?:(?>[^()]+)|(?&nrec))+\)))
            |
            (?:(?:.*?)${s}*+(?:$name))
         )${s}*+;
      /gmpx)
   {
      my $name = $+{name};
      my $o = C::Typedef->new(name => $name, code => ${^MATCH}, area => $area);

      if (exists $typedefs{$name}) {
         my $norm = sub { $_[0] =~ s/\s+//rg };
         foreach (@{ $set->set }) {
            if ($_->name eq $name) {
               my $i1 = $_->inside;
               my $i2 = $o->inside;
               my $warn = "Redefinition of typedef $name\nPrevious: " . $_->code . "\nCurrent: " . $o->code . "\n";

               if ($i1 && $i2) {
                  if ((@$i1 == 2) && (@$i2 == 2)) {
                     unless ($i1->[0] eq $i2->[0] && $i1->[1] eq $i2->[1]) {
                        warn($warn);
                        $_ = $o;
                     }
                  } else {
                     warn($warn);
                     $_ = $o;
                  }
               } elsif ($i2) {
                  $_ = $o
               } elsif ($norm->($_->code) ne $norm->($o->code)) {
                  warn($warn);
                  $_ = $o;
               }
               last
            }
         }
      } else {
         $typedefs{$name} = 1;
         $set->push($o);
      }
   }

   return $set;
}


__PACKAGE__->meta->make_immutable;

1;
