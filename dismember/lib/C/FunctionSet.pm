package C::FunctionSet;
use Moose;

use Carp;

use C::Function;
use Local::C::Transformation qw(:RE);
use Local::List::Utils qw(any);
use C::Keywords;
use namespace::autoclean;

use re '/aa';

extends 'C::Set';
with    'C::Parse';


has '+set' => (
   isa => 'ArrayRef[C::Function]'
);


sub index
{
   +{ $_[0]->map(sub { ($_->name, $_->id) }) }
}

sub parse
{
   my $self = shift;
   my $area = $_[1];
   my %functions;

   my $ret  = qr/(?<ret>[\w$Local::C::Transformation::special_symbols][\w\s\*$Local::C::Transformation::special_symbols]+)/;
   my $name = qr'(?<name>[a-zA-Z_]\w*+)';
   my $args = qr'(?>(?<args>\((?:(?>[^\(\)]+)|(?&args))*\)))';
   my $body = qr'(?>(?<fbody>\{(?:(?>[^\{\}]+)|(?&fbody))*\}))';
   
   #get list of all module functions
   while ( ${$_[0]} =~ m/$ret${s}*+\b$name${s}*+$args${s}*+$body/gp ) {
      my $name = $+{name};
      my $code = ${^MATCH}; 

      if (any($name, \@keywords)) {
         carp("Parsing error; function name: '$name'. Skipping.");
         next
      }

      if ($functions{$name}) {
         carp("Repeated defenition of function $name")
      }

      $functions{$name} = $code
   }
   
   return $self->new(set => [ map { C::Function->new(name => $_, code => $functions{$_}, area => $area) } keys %functions ]);
}

__PACKAGE__->meta->make_immutable;

1;
