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
   my ($self, $code, $area) = @_;
   my %declarations;

   #my $ret  = qr/(?<ret>[\w\s\*$C::Util::Transformation::special_symbols]+)/;
   my $ret  = qr/(?<ret>[\w$C::Util::Transformation::special_symbols][\w\s\*$C::Util::Transformation::special_symbols]+)/;
   my $name = qr/(?<name>$varname)/;
   my $args = qr'(?>(?<args>\((?:(?>[^\(\)]+)|(?&args))*\)))';
   my $fbody = qr'(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\}))';
   my $kbody = qr/(?:;|$fbody)/;
   my $mbody = qr/(?:;|$fbody(*SKIP)(*FAIL))/;
   my $body  = ($area eq 'module' ? $mbody : $kbody);

   while ($$code =~ m/($ret${s}*+\b$name${s}*+$args)${s}*+$body/g) {
      my $name = $+{name};
      next if index($+{ret}, 'typedef') != -1;
      next if (any($name, \@keywords));

      my $code = $1 . ';';
      if ($code =~ m/\A\s*+(${s}++)/) {
         my $spec = '';
         if ($+[1] > 0) {
            $spec = substr($code, $-[1], $+[1] - $-[1])
         }
         $code = $spec . normalize(substr($code, $+[1]));
      } else {
         $code = normalize($code);
      }

      unless (exists $declarations{$name}) {
         $declarations{$name} = C::Declaration->new(name => $name, code => $code, area => $area)
      }
   }

   return $self->new(set => [values %declarations]);
}


__PACKAGE__->meta->make_immutable;

1;
