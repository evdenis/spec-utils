package C::Fields;
use Moose::Role;
use namespace::autoclean;

sub up
{
   my $ref = $_[0]->fields->get($_[1]);
   if (defined $ref) {
      $ref->[0]++;
      $_[0]->fields->set($_[1] => $ref);
   }
}


1;
