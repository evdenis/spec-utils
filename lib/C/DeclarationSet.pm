package C::DeclarationSet;
use Moose;
use Hash::Ordered;

use RE::Common qw($varname);
use C::Util::Transformation qw(:RE);
use Local::String::Util qw(normalize);
use Local::List::Util qw(any);
use C::Keywords;

use C::Declaration;
use namespace::autoclean;

extends 'C::Set';
with    'C::Parse';

has '+set' => (
   isa => 'ArrayRef[C::Declaration]',
);

sub parse
{
   my $self = shift;

   my $declarations = Hash::Ordered->new();

   my $ret  = qr/(?<ret>[\w\s\*$C::Util::Transformation::special_symbols]+)/;
   my $name = qr/(?<name>$varname)/;
   my $args = qr'(?>(?<args>\((?:(?>[^\(\)]+)|(?&args))*\)))';
   my $body = qr'(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\}))';

   while ( ${$_[0]} =~ m/($ret${s}*+\b$name${s}*+$args)${s}*+(?:;|$body)/g ) {
      my $name = $+{name};
      next if index($+{ret}, 'typedef') != -1;
      next if (any($name, \@keywords));

      my $code = $1 . ';';
      $code = normalize($code);

      unless ($declarations->exists($name)) {
         $declarations->push($name => C::Declaration->new(name => $name, code => $code, area => $_[1]))
      }
   }

   return $self->new(set => [$declarations->values]);
}


__PACKAGE__->meta->make_immutable;

1;
