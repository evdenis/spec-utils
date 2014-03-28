package C::MacroSet;

use namespace::autoclean;
use Carp;
use Moose;

use C::Macro;

use re '/aa';

extends 'C::Set';

has '+set' => (
   isa => 'ArrayRef[C::Macro]',
   handles => {
      map             => 'map',
      get_from_index  => 'get'
   }
);

has 'index' => (
   is => 'rw',
   isa => 'HashRef[Str]',
   lazy => 1,
   builder => '_rebuild_index',
   traits => ['Hash'],
   handles => {
      exists    => 'exists',
      keys      => 'keys',
      get_index => 'get'
   }
);

sub _rebuild_index
{
   my $i = 0;
   +{ $_[0]->map(sub { ($_->name, $i++) }) }
}

sub push
{
   my $self = shift;

   my $i = $#{$self->set};
   foreach (@_) {
      push @{$self->set}, $_;
      $self->index->{$_->name} = ++$i;
   }
}

sub _build_ids
{
   [ $_[0]->map( sub { if ($_) { $_->get_code_ids } else {[]} } ) ];
}

sub _build_tags
{
   [ $_[0]->map( sub { if ($_) { $_->get_code_tags } else {[]} } ) ];
}

sub delete
{
		delete $_[0]->set->[ $_[0]->get_index($_[1]) ];
      delete $_[0]->index->{ $_[1] };
}

sub get
{
   $_[0]->get_from_index($_[0]->get_index($_[1]))
}

#FIXME: only oneline defines currently allowed
#TODO: parse_kernel_macro -> parse_macro
sub parse_kernel_macro
{
   my $self = shift;
   my %defines;

   foreach(@{$_[0]}) {
      chomp;

      if (
            m/\A
            [ \t]*+
            \#
            [ \t]*+
            define
            [ \t]++
            (?<def>[a-zA-Z_]\w*)
            (?:\([ \t]*(?<args>[^\)]*)\))?
            [ \t]*+
            (?<code>.*)\Z
         /xp) {
         my $name = $+{def};

         if (exists $defines{$name}) {
            carp("Repeated defenition of typedef $name")
         } else {
            my $code = ${^MATCH};
            my $substitution = $+{code};
            my $args = undef;

            if (exists $+{args}) {
               $args = [ $+{args} =~ m/[a-zA-Z_]\w*/g ]
            }

            $defines{$name} = C::Macro->new(name => $name, args => $args, code => $code, substitution => $substitution)
         }
      } else {
         carp("Can't parse $_");
      }
   }

   return $self->new(set => [ values %defines ]);
}


__PACKAGE__->meta->make_immutable;

1;
