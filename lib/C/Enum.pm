package C::Enum;
use Moose;
use utf8::all;

use RE::Common qw($varname);
use C::Util::Transformation qw(:RE);
use C::Keywords qw(prepare_tags);
use Local::String::Util qw(trim);
use Clone qw(clone);
use Hash::Ordered;

use namespace::autoclean;

extends 'C::Entity';

has 'has_name' => (
   is       => 'ro',
   isa      => 'Bool',
   default  => '1',
   required => 1
);

has 'get_code_ids' => (
   is       => 'ro',
   isa      => 'ArrayRef[Str]',
   lazy     => 1,
   builder  => '_build_code_ids',
   init_arg => undef
);

has 'fields' => (
   is       => 'rw',
   isa      => 'Hash::Ordered',
   init_arg => undef,
   default  => sub {Hash::Ordered->new()},
);

has 'fields_dependence' => (
   is       => 'rw',
   isa      => 'ArrayRef[ArrayRef[Int]]',
   init_arg => undef,
   default  => sub {[]},
);

has [qw(head tail)] => (
   is       => 'rw',
   isa      => 'Str',
   init_arg => undef
);

around BUILDARGS => sub {
   my $orig  = shift;
   my $class = shift;
   my $opts  = (ref $_[1] eq 'HASH') ? shift : {@_};

   unless (defined $opts->{name}) {
      $opts->{name}     = '';    #Will be set to first constant in BUILD
      $opts->{has_name} = 0;
   }
   $opts->{code} =~ s/}\s++;\z/};/;

   $class->$orig($opts);
};

sub BUILD
{
   my $self = shift;

   my $code = $self->code;
   my ($o, $c) = (index($code, '{') + 1, rindex($code, '}'));

   $self->head(substr($code, 0, $o));
   $self->tail(substr($code, $c));
   my @fields = split(/,/, substr($code, $o, $c - $o));

   $self->name($self->head =~ m/enum${s}++($varname)/)
     unless $self->has_name;

   my $last_expr_dep;
   foreach (@fields) {
      next if /\A${s}++\z/;

      if (m/\A${s}*+(${varname})(${s}*+=${s}*+)?/g) {
         my $f     = $1;
         my $field = [0, $_];

         my $arr = [];
         if (defined $2) {
            my $str = substr($_, $+[0]);
            foreach ($self->fields->keys) {
               if ($str =~ m/\b\Q$_\E\b/) {
                  push @$arr, 1;
               } else {
                  push @$arr, 0;
               }
            }
            # Validate that the expression only contains safe characters for arithmetic
            # Allow: digits, whitespace, operators (+, -, *, /, %, <<, >>), parentheses, and identifiers
            if ($str =~ /^[\w\s\+\-\*\/\%\(\)\<\>]+$/) {
               my $val = eval "{ use integer; no warnings; $str }";
               unless ($@) {
                  push @$field, ('value', $val);
               } else {
                  $last_expr_dep = $arr;
                  push @$field, ('expr', $str);
               }
            } else {
               # Expression contains unsafe characters, treat as non-evaluable
               $last_expr_dep = $arr;
               push @$field, ('expr', $str);
            }
         } else {
            $arr = $last_expr_dep
              if $last_expr_dep;
            push @$field, 'next';
         }
         push @{$self->fields_dependence}, $arr;

         $self->fields->set($f => $field);
      } else {
         warn "Can't parse '$_' string for enum ids\n";
      }
   }
}

sub _build_code_ids
{
   my $self = shift;
   my @a;

   push @a, $self->name
     if $self->has_name;
   push @a, $self->fields->keys;

   \@a;
}

sub get_code_tags
{
   my $filter = $_[0]->get_code_ids();

   #HACK
   if ($_[0]->has_name) {
      $filter = clone($filter);
      $filter->[0] = 'enum ' . $_[0]->name;
   }

   prepare_tags(substr($_[0]->code, index($_[0]->code, '{')), $filter);
}

sub up
{
   my $ref = $_[0]->fields->get($_[1]);
   if (defined $ref) {
      $ref->[0]++;
      $_[0]->fields->set($_[1] => $ref);
   }
}

sub to_string
{
   my $self = shift;

   return $self->code
     unless $_[1];

   my @keys = reverse $self->fields->keys;
   while (my ($i, $v) = each @keys) {
      if ($self->fields->get($v)->[0]) {
         my $dep = $self->fields_dependence->[$#keys - $i];
         while (my ($i, $b) = each @$dep) {
            $self->up($self->fields->[Hash::Ordered::_KEYS]->[$i])
              if $b;
         }
      }
   }

   my $skip            = 0;
   my $gap             = 0;
   my $last_value_type = 'n';
   my $last_value      = 0;
   my @body;
   foreach ($self->fields->keys) {
      my $ref = $self->fields->get($_);
      my $t   = $ref->[2];

      if ($ref->[0]) {
         my $val = $ref->[1];
         if ($skip && ($t eq 'next')) {
            if ($last_value_type eq 'n') {
               $last_value += $gap;
            } else {    #expr
               $last_value = "$last_value + $gap";
            }
            chomp $val;
            $val .= " = $last_value";
         }
         push @body, $val;

         if ($t eq 'value') {
            $last_value_type = 'n';
            $last_value      = $ref->[3];
         } elsif ($t eq 'expr') {
            $last_value_type = 'e';
            $last_value      = $ref->[3];
         }
         $gap  = 1;
         $skip = 0;
      } else {
         if ($t eq 'next') {
            ++$gap;
         } elsif ($t eq 'value') {
            $gap             = 1;
            $last_value_type = 'n';
            $last_value      = $ref->[3];
         } else {    # $t eq 'expr'
            $gap             = 1;
            $last_value_type = 'e';
            $last_value      = $ref->[3];
         }
         $skip = 1;
      }
   }

   if (@body == 0) {
      if ($self->has_name == 0) {
         warn "Enum doesn't have name and all constants are reducted.\n"
           if $ENV{DEBUG};
         return undef;
      } else {
         warn "There is no exploitable constants in Enum " . $self->name . ". Stub will be used.\n"
           if $ENV{DEBUG};
         push @body, "\n__STUB__" . uc($self->name);
      }
   }

   my $body = join(',', @body);
   chomp $body;
   my $head = $self->head;
   if (@body > 1) {
      $body .= "\n";
   } else {
      $head =~ s/\s++/ /g;
      $body = " " . trim($body) . " ";
   }

   $head . $body . $self->tail;
}

__PACKAGE__->meta->make_immutable;

1;
