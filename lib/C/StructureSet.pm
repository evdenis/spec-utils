package C::StructureSet;
use Moose;

use RE::Common qw($varname);
use C::Structure;
use C::Util::Transformation qw(:RE norm);
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with 'C::Parse';

has '+set' => (isa => 'ArrayRef[C::Structure]',);

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my %structures;

   my $name = qr!(?<sname>$varname)!;

   while (
      ${$_[0]} =~ m/^${h}*+
         (struct|union)
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
         )${s}*+(?:(?:__attribute__\h*+\(\(\h*+)?(?:__)?packed(:?\h*+\)\))?)?${s}*+;
      /gmpx
     )
   {
      my $name = $+{sname};
      my $code = ${^MATCH};
      my $type = $1;

      warn("Repeated defenition of structure $name\n")
        if (exists $structures{$name} && (norm($structures{$name}{code}) ne norm($code)));

      $structures{$name} = C::Structure->new(
         name => $name,
         code => $code,
         type => $type,
         area => $area
      );
   }

   return $self->new(set => [values %structures]);
}

__PACKAGE__->meta->make_immutable;

1;
