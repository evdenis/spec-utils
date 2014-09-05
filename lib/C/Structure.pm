package C::Structure;
use Moose;

use Moose::Util::TypeConstraints;
use Local::C::Parsing qw(_get_structure_wo_field_names);
use Local::C::Transformation qw(:RE);
use RE::Common qw($varname);
use C::Keywords qw(prepare_tags);
use Hash::Ordered;
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';


has 'type' => (
   is => 'ro',
   isa => enum([qw(struct union)]),
   required => 1
);

has 'fields' => (
   is => 'rw',
   isa => 'Hash::Ordered',
   init_arg => undef,
   default => sub { Hash::Ordered->new() },
);

has [qw/head tail/] => (
   is => 'rw',
   isa => 'Str',
   init_arg => undef
);


around BUILDARGS => sub {
   my $orig = shift;
   my $class = shift;
   my $opts = ( ref $_[1] eq 'HASH' ) ? shift : { @_ };

   $opts->{code} =~ s/}\s++;\z/};/;

   $class->$orig($opts)
};

sub BUILD
{
   my $self = shift;

   my $code = $self->code;
   my ($o, $c) = (index($code, '{') + 1, rindex($code, '}'));

   $self->head(substr($code, 0, $o));
   $self->tail(substr($code, $c));


   my $r = 0;
   my $stub_count = 0;
   my @buf;
   my $l;
   my @lines = split(/(?<=;)/, substr($code, $o, $c - $o));
   while ($l = shift @lines) {
      next if $l =~ m/\A\s++\Z/;

      if (index($l, '{') != -1) {
         splice(@lines, 0, 0, split(/(?<={)/, $l));
         ++$r;
         $l = shift @lines;
      }

      if ($r) {
         if (index($l, '}') != -1) {
            #TODO: don't ignore internal structures
            $self->fields->set("--STUB" . $stub_count++ . "--" => [1, join('', @{ $buf[$r] }, $l)]);
            $buf[$r] = [];
            --$r
         } else {
            push @{ $buf[$r] }, $l
         }
      } else {
         my $fieldname;

         if ($l =~ m/\(${h}*+\*${h}*+($varname)${h}*+\)${h}*+\(/) {
            $fieldname = $1
         } else {
            my $name_ex = qr/($varname)(?:\[[^\]]+\]|:\d+)?/;

            if ((my $several = index($l, ',')) != -1) {
               my @v = split(/,/, $l);
               my $type;
               if ($v[0] =~ m/\b${name_ex}${h}*+\z/) {
                  $type = substr($l, 0, $-[0])
               } else {
                  warn "Can't determine type in string '$v[0]'\n";
                  next
               }

               $_ =~ s/\s++//g foreach @v[1..$#v];
               splice(@lines, 0, 0, $v[0] . ';', map($type . $_ . ';', @v[1 .. $#v - 1]), $type . $v[-1]);
               next
            } elsif ($l =~ m/${name_ex}${h}*+;/) {
               $fieldname = $1;
            } else {
               warn "Can't determine field name in string '$l'\n";
               next
            }
         }

         $self->fields->set($fieldname => [0, $l])
      }
   }
}

sub get_code_ids
{
   [ $_[0]->name,
      [
         grep {m/\A[^-]/} $_[0]->fields->keys
      ]
   ]
}

sub up
{
   my $ref = $_[0]->fields->get($_[1]);
   if (defined $ref) {
      $ref->[0]++;
      $_[0]->fields->set($_[1] => $ref);
   }
}

sub get_code_tags
{
   my $code = $_[0]->code;

   my $filter = [$_[0]->type . ' ' . $_[0]->name]; #instead if get_code_ids
   $code = _get_structure_wo_field_names($code);

   prepare_tags($code, $filter)
}

sub to_string
{
   my $self = shift;

   return $self->code
      unless $_[1];

   my @body;

   foreach ($self->fields->keys) {
      my $ref = $self->fields->get($_);
      push @body, $ref->[1]
         if $ref->[0]
   }

   if (@body) {
      $self->head . join('', @body) . "\n" . $self->tail
   } else {
      ''
   }
}

__PACKAGE__->meta->make_immutable;

1;
