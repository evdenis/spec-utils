package C::Typedef;
use Moose;

use Moose::Util::TypeConstraints;
use RE::Common qw($varname);
use C::Util::Parsing qw(_get_structure_wo_field_names);
use C::Util::Transformation qw(:RE);
use C::Keywords qw(prepare_tags);
use C::Enum;
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';

has 'inside' => (
   is       => 'ro',
   isa      => 'Maybe[ArrayRef[Str]]',
   lazy     => 1,
   builder  => '_build_inside',
   init_arg => undef
);

#only to mimic struct
has 'type' => (
   is       => 'ro',
   isa      => enum([qw(empty struct union enum)]),
   lazy     => 1,
   builder  => '_get_type',
   init_arg => undef
);

sub _build_inside
{
   if ($_[0]->code =~ m/typedef${s}*+(union|struct|enum)${s}*+($varname)?${s}*+\{/) {
      return $2 ? [$1, $2] : [$1];
   }

   undef;
}

sub _get_type
{
   if ($_[0]->inside) {
      return @{$_[0]->inside}[0];
   }

   'empty';
}

sub get_code_ids
{
   my $code   = $_[0]->code;
   my @result = ($_[0]->name);

   my $i = $_[0]->inside;
   if ($i) {
      push @result, $i->[1]
        if @$i == 2;

      if ($i->[0] eq 'enum') {
         my $ids = C::Enum->new(name => $i->[1], code => $code, area => $_[0]->area)->get_code_ids;
         push @result, @$ids;
      }
   }

   \@result;
}

sub get_code_tags
{
   my $code   = $_[0]->code;
   my $filter = $_[0]->get_code_ids;

   my $i = $_[0]->inside;
   if ($i) {
      $code = _get_structure_wo_field_names($code)
        if $i && (@$i[0] eq 'struct' || @$i[0] eq 'union');

      push @$filter, join(' ', @$i)
        if @$i == 2;
   }

   prepare_tags($code, $filter);
}

__PACKAGE__->meta->make_immutable;

1;
