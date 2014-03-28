package C::Enum;
use namespace::autoclean;
use Moose;

use Local::C::Transformation qw(:RE);
use Local::String::Utils qw(normalize);

extends 'C::Entity';

has 'has_name' => (
   is => 'ro',
   isa => 'Bool',
   default => '1',
   required => 1,
);

has 'get_code_ids' => (
   is => 'ro',
   isa => 'ArrayRef[Str]',
   lazy => 1,
   builder => '_build_code_ids'
);

around BUILDARGS => sub {
   my $orig = shift;
   my $class = shift;
   my $opts = ( ref $_[1] eq 'HASH' ) ? shift : { @_ };

   if (!defined $opts->{name}) {
      $opts->{name} = ''; #Will be set to first constant in BUILD
      $opts->{has_name} = 0;
   }

   $class->$orig($opts)
};

sub BUILD {
   my $self = shift;

   $self->name($self->get_code_ids->[0])
      unless ($self->has_name);
}

sub _build_code_ids
{
   my $self = shift;
   my @a;

   if ($self->has_name) {
      push @a, $self->name
   }

   my $code = $self->code;
   my ($o, $c) = (index($code, '{') + 1, rindex($code, '}'));

   my @fields = split(/,/, substr($code, $o, $c - $o));

   foreach (@fields) {
      next if /\A\s+\z/;

      if (m/\A${s}*+([a-zA-Z_]\w*)(?:${s}*+=${s}*+)?/) {
         push @a, $1
      } else {
         warn("Can't parse '$_' string for enum ids\n")
      }
   }

   \@a
}


__PACKAGE__->meta->make_immutable;

1;
