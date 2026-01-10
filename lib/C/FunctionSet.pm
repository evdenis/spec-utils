package C::FunctionSet;
use Moose;
use utf8::all;

use RE::Common qw($varname);
use C::Function;
use C::Util::Transformation qw(:RE filter_dup norm);
use Local::List::Util qw(any);
use Local::String::Util qw(normalize);
use C::Keywords;
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with 'C::Parse';

has '+set' => (isa => 'ArrayRef[C::Function]');

sub index
{
   +{$_[0]->map(sub {($_->name, $_->id)})};
}

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my %functions;

   my $ret =
     qr/(?<ret>[\w$C::Util::Transformation::special_symbols][\w\s\*$C::Util::Transformation::special_symbols]+)/;
   my $name  = qr/(?<name>$varname)/;
   my $attrs = qr/(?:${s}*+(?:__releases|__acquires)${s}*+\([^)]++\))*+/;
   my $args  = qr'(?>(?<args>\((?:(?>[^\(\)]+)|(?&args))*\)))';
   my $body  = qr'(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\}))';

   #get list of all module functions
   while (${$_[0]} =~ m/${ret}${s}*+\b${name}${s}*+${args}${s}*+${attrs}?${s}*+${body}/gp) {
      my ($ret, $name, $args, $fbody) = @+{qw(ret name args fbody)};
      my $code = ${^MATCH};
      my $decl = normalize(filter_dup("${ret} ${name}${args};"));

      if (any($name, \@keywords)) {
         warn "Parsing error; function name: '$name'. Skipping.\n";
         next;
      }

      if ($functions{$name}) {
         if (norm($functions{$name}{code}) ne norm($code)) {
            warn "Repeated definition of function $name\n";
         } else {
            warn "Repeated definition of function $name. Missing header guard?\n";
         }
      }

      @{$functions{$name}}{qw(code declaration ret args body)} = ($code, $decl, $ret, $args, $fbody);
   }

   return $self->new(set => [map {C::Function->new(name => $_, %{$functions{$_}}, area => $area)} keys %functions]);
}

__PACKAGE__->meta->make_immutable;

1;
