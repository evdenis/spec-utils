package C::Declaration;
use Moose;

use Local::C::Parsing qw(_argname);
use C::Keywords qw(prepare_tags);
use Local::C::Transformation qw(:RE);
use Local::List::Utils qw(difference);
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';


sub get_code_tags
{
   my $self = shift;
   my $code = $self->code;

   my ($begin, $end) = (index($code, '(') + 1, rindex($code, ')'));
   $code = substr($code, $begin, $end - $begin);

   my @args;
   foreach(split(/,/, $code)) {
      next if m/\A${s}*+\z/;
      my @names = _argname($_);

      push @args, @names if @names;
   }

   my $filter = $self->get_code_ids();
   push @$filter, @args;

   prepare_tags($self->code, $filter)
}

sub to_string
{
   my $code = $_[0]->code;
   $code = 'extern ' . $code if $code =~ s!\A${s}*+\K(static\h++inline)!/*$1*/!;

   $code
}

__PACKAGE__->meta->make_immutable;

1;
