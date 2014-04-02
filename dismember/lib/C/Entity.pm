package C::Entity;
use Moose;

use Moose::Util::TypeConstraints;
use Local::List::Utils qw(difference);
use C::Keywords qw(@keywords_to_filter);
use namespace::autoclean;

use feature qw(state);
use re '/aa';


has 'id' => (
   is => 'ro',
   isa => 'Str',
   required => 1,
   builder => '_compose_id',
   init_arg => undef
);

sub _compose_id
{
   state $i = 0;

   $i++
}


has 'name' => (
   is => 'rw',
   isa => 'Str',
   required => 1
);

has 'code' => (
   is => 'ro',
   isa => 'Str',
   required => 1
);

has 'area' => (
   is => 'ro',
   isa => enum([qw(kernel module)]),
   required => 1
);

sub to_string
{
   $_[0]->code
}

sub get_code_ids
{
   [ $_[0]->name ]
}

sub get_code_tags
{
   my @list = ($_[0]->code =~ m/\b[a-zA-Z_]\w*+\b/g);

   my $filter = $_[0]->get_code_ids();
   push @$filter, @keywords_to_filter;

   [ difference(\@list, $filter) ]
}


__PACKAGE__->meta->make_immutable;

1;
