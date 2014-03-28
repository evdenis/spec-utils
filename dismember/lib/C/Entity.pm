package C::Entity;
use namespace::autoclean;
use Moose;

use Local::List::Utils qw(difference);
use Local::C::Parse qw(@keywords);

use feature qw(state);
use re '/aa';


has 'id' => (
   is => 'ro',
   isa => 'Str',
   required => 1,
   builder => '_compose_id'
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
   my @list = ($_[0]->code =~ m/\b[a-zA-Z_]\w*\b/g);

   my $filter = $_[0]->get_code_ids();
   push @$filter, @keywords;

   [ difference(\@list, $filter) ]
}


__PACKAGE__->meta->make_immutable;

1;
