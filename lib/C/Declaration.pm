package C::Declaration;
use Moose;

use C::Util::Parsing qw(_argname);
use C::Keywords qw(prepare_tags);
use C::Util::Transformation qw(:RE filter_comments_dup);
use Local::List::Util qw(difference);
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

sub clean_comments
{
   $_[0]->code(filter_comments_dup($_[0]->code));

   undef
}

sub add_spec
{
   my $code = $_[0]->code;
   $code =~ s/\A\s++//;

   $_[0]->code("/*@\n" . $_[1] . "\n*/\n" . $code);

   undef
}

sub to_string
{
   my $code = $_[0]->code;
   $code =~ s!\A${s}*+\K(static\h++inline)!extern /*$1*/!;

   $code
}

__PACKAGE__->meta->make_immutable;

1;
