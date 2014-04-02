package C::Structure;
use Moose;

use Local::C::Parse qw(_argname_exists);
use Local::C::Transformation qw(:RE);
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';


sub get_fields
{
   my $self = shift;
   my $code = $self->code;
   my ($begin, $end) = (index($code, '{') + 1, rindex($code, '}'));

   $code = substr($code, $begin, $end - $begin);

   my @fields;
   foreach(split(/;/, $code)) {
      next if m/\A${s}*+\z/;

      push @fields, _argname_exists($_)
   }

   \@fields
}


__PACKAGE__->meta->make_immutable;

1;
