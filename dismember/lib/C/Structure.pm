package C::Structure;
use namespace::autoclean;
use Moose;

extends 'C::Entity';

use re '/aa';


sub _argname
{
   if ($_[0] =~ m/(?|([a-zA-Z_]\w*)(?:\[[^\]]+\]|:\d+)?\h*+\Z|\(\h*\*\h*([a-zA-Z_]\w*)\h*\)\h*\()/) {
      return $1
   }
   undef
}


sub get_fields
{
   my $self = shift;
   my $code = $self->code;
   my ($begin, $end) = (index($code, '{') + 1, rindex($code, '}'));

   $code = substr($code, $begin, $end - $begin);

   my @fields;
   foreach(split(/;/, $code)) {
      next if m/\A\s*\z/;

      push @fields, _argname($_)
   }

   \@fields
}


__PACKAGE__->meta->make_immutable;

1;
