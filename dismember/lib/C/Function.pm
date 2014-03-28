package C::Function;
use namespace::autoclean;
use Moose;

extends 'C::Entity';

has 'forward_declaration' => (
   is => 'rw',
   isa => 'ArrayRef[Str]',
   lazy => 1,
   init_arg => undef,
   default => sub { [] },
   traits => ['Array'],
   handles => {
      add_fw_decl => 'push'
   }
);

sub to_string
{
   my $str;

   $str = join("\n", @{ $_[0]->forward_declaration }) . "\n\n";
   $str .= $_[0]->code;

   $str
}


__PACKAGE__->meta->make_immutable;

1;
