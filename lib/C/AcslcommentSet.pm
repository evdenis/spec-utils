package C::AcslcommentSet;
use Moose;

use RE::Common qw($varname);
use Carp;
use C::Acslcomment;
use ACSL::Common qw(is_acsl_spec);
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with    'C::Parse';

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my @acsl_comments;

   while(my ($i, $c) = each @{$_[0]}) {
      if (is_acsl_spec($c)) {
         push @acsl_comments, C::Acslcomment->new(name => "acsl_spec_$i",
                                                  code => $c,
                                                  replacement_id => $i,
                                                  area => $area);
      }
   }

   return $self->new(set => \@acsl_comments);
}


__PACKAGE__->meta->make_immutable;

1;
