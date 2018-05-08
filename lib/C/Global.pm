package C::Global;
use Moose;
use C::Util::Transformation qw(:RE);
use namespace::autoclean;

extends 'C::Entity';

has 'initialized' => (
   is      => 'ro',
   isa     => 'Bool',
   lazy    => 1,
   builder => '_build_initialized'
);

has 'initializer' => (
   is      => 'ro',
   isa     => 'Str',
   lazy    => 1,
   builder => '_build_initializer'
);

has 'type' => (
   is       => 'rw',
   isa      => 'Str',
   required => 1
);

has 'modifier' => (
   is  => 'rw',
   isa => 'Maybe[Str]'
);

has 'extern' => (
   is      => 'ro',
   isa     => 'Bool',
   lazy    => 1,
   builder => '_is_extern'
);

sub _build_initialized
{
   index($_[0]->code, '=') != -1;
}

sub _build_initializer
{
   my $str = substr($_[0]->code, index($_[0]->code, '=') + 1);
   $str =~ m/${s}*+(.*?)${s}*+;/;
   return $1;
}

sub to_string
{
   my $code = $_[0]->code;

   #if ((my $i = index($code, '=')) != -1) {
   #   $code = substr($code, 0, $i) . ';';
   #   #$code =~ s/^static/extern/; Do we really need it?
   #}

   $code;
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
