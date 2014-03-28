package C::StructureSet;
use namespace::autoclean;
use Moose;

use C::Structure;
use Local::C::Transformation qw(:RE);

use re '/aa';

extends 'C::Set';

has '+set' => (
   isa => 'ArrayRef[C::Structure]',
);

sub parse_structure
{
   my $self = shift;
   my %structures;

   my $name = qr!(?<sname>[a-zA-Z_]\w*)!;
   
   while ( $_[0] =~ m/^${h}*+
         (?:struct|union)
         ${s}++
            $name
         ${s}*+
         (?>
            (?<sbody>
            \{
               (?:
                  (?>[^\{\}]+)
                  |
                  (?&sbody)
               )*
            \}
            )
         )${s}*+;
      /gmpx) {
      carp("Repeated defenition of structure $+{sname}") if (exists $structures{$+{sname}});
      $structures{$+{sname}} = ${^MATCH}
   }

   return $self->new(set => [ map { C::Structure->new(name => $_, code => $structures{$_}) } keys %structures ]);
}


__PACKAGE__->meta->make_immutable;

1;
