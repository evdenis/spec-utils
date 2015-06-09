package C::EnumSet;
use Moose;

use RE::Common qw($varname);
use C::Enum;
use C::Util::Transformation qw(:RE);
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
   my @enums;

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
      push @enums, C::Enum->new(name => $+{ename}, code => ${^MATCH}, area => $_[1])
   }

   return $self->new(set => \@enums);
}


__PACKAGE__->meta->make_immutable;

1;
