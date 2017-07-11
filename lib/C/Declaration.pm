package C::Declaration;
use Moose;

use C::Util::Parsing qw(_argname);
use C::Keywords qw(prepare_tags);
use C::Util::Transformation qw(:RE %comment_t filter_comments_dup);
use ACSL::Common qw(is_acsl_spec);
use Local::List::Util qw(difference);
use namespace::autoclean;

use re '/aa';

extends 'C::Entity';

has 'spec_ids' => (
   isa => 'ArrayRef[Int]',
   is => 'ro',
   lazy => 1,
   init_arg => undef,
   builder => '_build_specs'
);

sub _build_specs
{
   [ $_[0]->code =~ m/$comment_t{pattern}/g ]
}

sub get_code_tags
{
   my $self = shift;
   my $code = $self->code;

   my ($begin, $end) = (index($code, '(') + 1, rindex($code, ')'));
   $code = substr($code, $begin, $end - $begin);

   my @args;
   foreach(split(/,/, $code)) {
      next if m/\A${s}*+\z/;
      my @names = _argname($_);

      push @args, @names if @names;
   }

   my $filter = $self->get_code_ids();
   push @$filter, @args;

   prepare_tags($self->code, $filter)
}

sub clean_comments
{
   $_[0]->code(filter_comments_dup($_[0]->code));

   undef
}

sub add_spec
{
   my $code = $_[0]->code;
   $code =~ s/\A\s++//;

   $_[0]->code("/*@\n" . $_[1] . "\n*/\n" . $code);

   undef
}

sub to_string
{
   my $code = $_[0]->code;
   my $comments = $_[1];
   #$code =~ s!\A${s}*+\K(static\h++inline)!extern /*$1*/!;

   my @cmnt = $code =~ m/$comment_t{pattern}/g;
   foreach (@cmnt) {
      if (is_acsl_spec($comments->[$_])) {
         my $pos = index($code, $comment_t{L} . $_ . $comment_t{R});
         $code = substr($code, $pos);
         goto FW_DECL
      }
   }
   # remove all comments since there is no specification binded to declaration
   $code =~ s/^${s}++//;

FW_DECL:

   $code
}

__PACKAGE__->meta->make_immutable;

1;
