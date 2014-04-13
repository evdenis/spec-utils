package C::Enum;
use Moose;

use Local::C::Transformation qw(:RE);
use Local::String::Utils qw(normalize);
use C::Keywords qw(prepare_tags);
use namespace::autoclean;

extends 'C::Entity';

has 'has_name' => (
   is => 'ro',
   isa => 'Bool',
   default => '1',
   required => 1
);

has 'get_code_ids' => (
   is => 'ro',
   isa => 'ArrayRef[Str]',
   lazy => 1,
   builder => '_build_code_ids',
   init_arg => undef
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

sub get_code_tags
{
   my $filter = $_[0]->get_code_ids();

   $filter->[0] = "enum " . $_[0]->name if $_[0]->has_name; #HACK

   prepare_tags(substr($_[0]->code, index($_[0]->code, '{')), $filter)
}

__PACKAGE__->meta->make_immutable;

1;