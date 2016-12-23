package C::Global;
use Moose;
use namespace::autoclean;

extends 'C::Entity';

has 'initialized' => (
   is      => 'ro',
   isa     => 'Bool',
   lazy    => 1,
   builder => '_build_initialized'
);

has 'type' => (
   is => 'rw',
   isa => 'Str',
   required => 1
);

has 'modifier' => (
   is => 'rw',
   isa => 'Maybe[Str]'
);

has 'extern' => (
   is => 'ro',
   isa => 'Bool',
   lazy => 1,
   builder => '_is_extern'
);


sub _build_initialized
{
   index($_[0]->code, '=') != -1
}

sub to_string
{
   my $code = $_[0]->code;

   #if ((my $i = index($code, '=')) != -1) {
   #   $code = substr($code, 0, $i) . ';';
   #   #$code =~ s/^static/extern/; Do we really need it?
   #}

   $code
}

sub _is_extern
{
   my $modifier = $_[0]->modifier;

   if ($modifier) {
      return index($modifier, 'extern') != -1;
   } else {
      return 0;
   }
}


__PACKAGE__->meta->make_immutable;

1;
