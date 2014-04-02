package C::Typedef;
use Moose;

use Local::C::Parsing qw(_get_structure_fields);
use Local::C::Transformation qw(:RE);
use C::Keywords qw(prepare_tags);
use namespace::autoclean;

use re '/aa';


extends 'C::Entity';


sub get_code_tags
{
   my $code = $_[0]->code;
   my $filter = $_[0]->get_code_ids();

   if ($code =~ m/typedef${s}*+(?:union|struct)${s}*+\{/) {
      my ($begin, $end) = ($+[0] + 1, rindex($code, '}'));
      $code = substr($code, $begin, $end - $begin);
      push @$filter, @{ _get_structure_fields($code) };
   }

   prepare_tags($code, $filter)
}

__PACKAGE__->meta->make_immutable;

1;
