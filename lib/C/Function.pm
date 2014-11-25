package C::Function;
use Moose;

use Local::C::Parsing qw(_argname_exists);
use C::Keywords qw(prepare_tags);
use Local::C::Transformation qw(:RE %comment_t);
use Local::List::Utils qw(difference);
use ACSL::Common qw(is_acsl_spec);

use namespace::autoclean;

use re '/aa';

extends 'C::Entity';


has 'forward_declaration' => (
   is => 'rw',
   isa => 'ArrayRef[Str]',
   lazy => 1,
   init_arg => undef,
   default => sub { [] },
   traits => ['Array'],
   handles => {
      add_fw_decl => 'push'
   }
);

has [qw/ret args body/] => (
   is => 'ro',
   isa => 'Str',
   required => 1
);


sub get_code_tags
{
   my $self = shift;
   my $code = $self->code;
   my $name = $self->name;

   $code =~ s/\b\Q$name\E\b//;

   prepare_tags($code, []);
   ##
   # Exclude function argument names from tags.
   # Not effective because argnames coincide with
   # names of other entries.
   ##
   #my $code = $self->code;
   #my $begin = index($code, '(') + 1;
   #$code =~ m/\)${s}*+\{/;
   #my $end = $-[0];
   #$code = substr($code, $begin, $end - $begin);
   #
   #my $filter;
   #$filter = $self->get_code_ids();
   #
   #my @args;
   #if ($code !~ m/\A${s}*+(?:void)?${s}*+\z/) {
   #   foreach(split(/,/, $code)) {
   #      next if m/\A${s}*+(?:\.{3}${s}*+)?\z/;
   #
   #      push @args, _argname_exists($_)
   #   }
   #}
   #
   #push @$filter, @args;
   #prepare_tags($self->code, $filter)
}

sub to_string
{
   my $str = '';
   my $comments = $_[1];
   my $code = $_[0]->code;

   my @cmnt = $code =~ m/$comment_t{pattern}/g;

   #crop to first spec comment
   foreach (@cmnt) {
      if (is_acsl_spec($comments->[$_])) {
         $code = substr($code, index($code, $comment_t{L} . $_ . $comment_t{R}));
         goto FW_DECL
      }
   }
   $code =~ s/^${s}++//;


FW_DECL:

   my $fw_decl = $_[0]->forward_declaration;
   if (@$fw_decl) {
      $str = join("\n", @$fw_decl) . "\n\n";
   }

   $str .= $code;
}


__PACKAGE__->meta->make_immutable;

1;
