package C::DeclarationSet;
use namespace::autoclean;
use Moose;

use Local::C::Transformation qw(:RE);
use Local::String::Utils qw(normalize);
use Local::List::Utils qw(any);
use Local::C::Parse qw(@keywords);

use C::Declaration;

extends 'C::Set';

has '+set' => (
   isa => 'ArrayRef[C::Declaration]',
);

#FIXME: wrong parsing
sub parse_declaration
{
   my $self = shift;

   my %declarations;

   my $ret  = qr/(?<ret>[\w\s\*$Local::C::Transformation::special_symbols]+)/;
   my $name = qr'(?<name>[a-zA-Z_]\w*+)';
   my $args = qr'(?>(?<args>\((?:(?>[^\(\)]+)|(?&args))*\)))';
   my $body = qr'(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\}))';

   while ( $_[0] =~ m/($ret${s}*+\b$name${s}*+$args${s}*+)(?:;|$body)/g ) {
      my $name = $+{name};
      next if index($+{ret}, 'typedef') != -1;
      next if (any($name, \@keywords));

      my $code = $1 . ';';
      $code = normalize($code);
      $code = 'extern ' . $code if $code =~ s!\A${s}*+\K(static\h++inline)!/*$1*/!;

      if (!exists $declarations{$name}) {
         $declarations{$name} = C::Declaration->new(name => $name, code => $code)
      }
   }

   return $self->new(set => [values %declarations]);
}


__PACKAGE__->meta->make_immutable;

1;
