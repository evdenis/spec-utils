package C::DeclarationSet;
use Moose;

use RE::Common qw($varname);
use Local::C::Transformation qw(:RE);
use Local::String::Utils qw(normalize);
use Local::List::Utils qw(any);
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

   my %declarations;

   my $ret  = qr/(?<ret>[\w\s\*$Local::C::Transformation::special_symbols]+)/;
   my $name = qr/(?<name>$varname)/;
   my $args = qr'(?>(?<args>\((?:(?>[^\(\)]+)|(?&args))*\)))';
   my $body = qr'(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\}))';

   while ( ${$_[0]} =~ m/($ret${s}*+\b$name${s}*+$args)${s}*+(?:;|$body)/g ) {
      my $name = $+{name};
      next if index($+{ret}, 'typedef') != -1;
      next if (any($name, \@keywords));

      my $code = $1 . ';';
      $code = normalize($code);

      unless (exists $declarations{$name}) {
         $declarations{$name} = C::Declaration->new(name => $name, code => $code, area => $_[1])
      }
   }

   return $self->new(set => [values %declarations]);
}


__PACKAGE__->meta->make_immutable;

1;
