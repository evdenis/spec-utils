package C::Declaration;
use Moose;

use Local::C::Parsing qw(_argname);
use C::Keywords qw(@keywords_to_filter);
use Local::C::Transformation qw(:RE);
use Local::List::Utils qw(difference);
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';

#FIXME: code duplication with Function
has 'get_code_tags' => (
   is => 'ro',
   isa => 'ArrayRef[Str]',
   lazy => 1,
   builder => '_build_code_tags',
   init_arg => undef
);


sub _build_code_tags
{
   my $self = shift;
   my $code = $self->code;

   my @list = ($code =~ m/\b[a-zA-Z_]\w*+\b/g);

   my ($begin, $end) = (index($code, '(') + 1, rindex($code, ')'));
   $code = substr($code, $begin, $end - $begin);

   my @args;
   foreach(split(/,/, $code)) {
      next if m/\A${s}*+\z/;
      my $name = _argname($_);

      push @args, $name if $name;
   }

   my $filter = $self->get_code_ids();
   push @$filter, @keywords_to_filter;
   push @$filter, @args;

   [ difference(\@list, $filter) ]
}


__PACKAGE__->meta->make_immutable;

1;
