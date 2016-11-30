package C::EnumSet;
use Moose;

use RE::Common qw($varname);
use C::Enum;
use C::Util::Transformation qw(:RE norm);
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with    'C::Parse';

has '+set' => (
   isa => 'ArrayRef[C::Enum]',
);


#FIXME: check for duplicates?
sub parse
{
   my $self = shift;
   my $area = $_[1];
   my %enums;

   my $name = qr!(?<ename>$varname)!;
   
   while ( ${$_[0]} =~ m/^${h}*+
         enum
         ${s}++
            (?:$name)?
         ${s}*+
         (?>
            (?<ebody>
            \{
               (?:
                  (?>[^\{\}]+)
                  |
                  (?&ebody)
               )*
            \}
            )
         )${s}*+;
      /gmpx) {
      my $code = ${^MATCH};
      my $ename = $+{ename};
      my $id = $ename || norm(substr($code,0,256));

      if (exists $enums{$id} && (norm($enums{$id}{code}) ne norm($id))) {
         warn "Redefinition of enum " . ($ename ? $ename : $id) . "\n";
      }
      $enums{$id} = { name => $ename, code => $code };
   }

   return $self->new(set => [
           map { C::Enum->new(
               name => $enums{$_}{name},
               code => $enums{$_}{code},
               area => $area) } keys %enums
       ]
   );
}


__PACKAGE__->meta->make_immutable;

1;
