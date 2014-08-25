package C::Global;
use Moose;
use namespace::autoclean;

extends 'C::Entity';

sub to_string
{
   my $code = $_[0]->code;

   if ((my $i = index($code, '=')) != -1) {
      $code = substr($code, 0, $i) . ';';
      $code =~ s/^static/extern/;
   }

   $code
}


__PACKAGE__->meta->make_immutable;

1;
