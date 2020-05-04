package C::Function;
use Moose;

use C::Util::Parsing qw(_argname_exists parse_calls);
use C::Keywords qw(prepare_tags);
use C::Util::Transformation qw(:RE %comment_t filter_comments_dup restore_comments norm);
use Local::List::Util qw(difference);
use Local::String::Util qw(ltrim rtrim);
use ACSL::Common qw(is_acsl_spec is_contract);

use namespace::autoclean;

use re '/aa';

extends 'C::Entity';

has 'declaration' => (
   is  => 'ro',
   isa => 'Str'
);

has 'forward_declaration' => (
   is       => 'rw',
   isa      => 'ArrayRef[Str]',
   lazy     => 1,
   init_arg => undef,
   default  => sub {[]},
   traits   => ['Array'],
   handles  => {add_fw_decl => 'push'}
);

has 'spec_ids' => (
   isa      => 'ArrayRef[Int]',
   is       => 'rw',
   lazy     => 1,
   init_arg => undef,
   builder  => '_build_specs'
);

has 'calls' => (
   isa      => 'ArrayRef[Str]',
   is       => 'ro',
   lazy     => 1,
   init_arg => undef,
   builder  => '_build_calls'
);

has [qw(ret args body)] => (
   is       => 'ro',
   isa      => 'Str',
   required => 1
);

sub _build_calls
{
   parse_calls($_[0]->code);
}

sub _build_specs
{
   [$_[0]->code =~ m/$comment_t{pattern}/g];
}

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

sub clean_comments
{
   $_[0]->code(filter_comments_dup($_[0]->code));

   undef;
}

sub add_spec
{
   my $code = $_[0]->code;
   $code =~ s/\A\s++//;

   $_[0]->code("/*@\n" . $_[1] . "\n*/\n" . $code);

   undef;
}

# 1 spec_id
# 2 spec_code
sub can_detach_specification
{
   my $code      = $_[0]->code;
   my $br        = index($code, '(');
   my $spec_decl = substr($code, 0, $br);

   if (index($spec_decl, $comment_t{L} . $_[1] . $comment_t{R}) != -1) {
      return !is_contract($_[2]);
   } else {
      # inside function
      return 0;
   }
}

sub detach_specification
{
   my $code    = $_[0]->code;
   my $spec_id = $_[1];
   $code =~ s/\Q$comment_t{L}\E${spec_id}\Q$comment_t{R}\E\s*+//;
   $_[0]->code($code);

   # remove id from spec_ids
   my @ids = @{$_[0]->spec_ids};
   @ids = grep {$_ != $spec_id} @ids;
   $_[0]->spec_ids(\@ids);
}

sub attach_declaration
{
   my ($self, $decl, $specs) = @_;
   my $contract_re = qr/\A\s*+(?<contract>${s}*)/;

   if ($decl->code =~ $contract_re) {
      my $decl_contract = $+{contract};
      my $code          = $self->code();
      my $contract      = $decl_contract;
      my $defn_start    = 0;
      my @comment_ids;

      if ($code =~ $contract_re) {
         my $defn_contract = $+{contract};
         $defn_start = $-[0];
         my $defn_end = $+[0];

         if ($defn_contract) {
            restore_comments($decl_contract, $specs);
            $decl_contract =~ s/$comment_t{pattern}/push @comment_ids, $1; ''/ge;
            my $norm_decl_contract = norm($decl_contract);

            return
              if !$norm_decl_contract;

            restore_comments($defn_contract, $specs);
            $defn_contract =~ s/$comment_t{pattern}/push @comment_ids, $1; ''/ge;
            my $norm_defn_contract = norm($defn_contract);

            @comment_ids = sort {$a <=> $b} @comment_ids;

            if ($norm_defn_contract && $norm_decl_contract) {
               if ($norm_defn_contract ne $norm_decl_contract) {
                  warn "Function "
                    . $self->name
                    . " has the decl contract and the defn contract that differs: \n"
                    . "Declaration:\n$decl_contract"
                    . "Definition:\n$defn_contract"
                    . "The definition contract will be used.\n";
                  return;
               } else {
                  $defn_start = $defn_end;
               }
            }
         }
      }

      if ($contract) {
         # disable to_string crop to work
         if (@comment_ids) {
            my $remove_comments = "\Q$comment_t{L}\E" . '(?:' . join('|', @comment_ids) . ')' . "\Q$comment_t{R}\E";
            $remove_comments = qr/$remove_comments/;

            $contract =~ s/$remove_comments//g;
            $code     =~ s/$remove_comments//g;

            $code       = ltrim $code;
            $contract   = rtrim $contract;
            $defn_start = 0;

            $contract = join("\n", map {$comment_t{L} . $_ . $comment_t{R}} @comment_ids) . "\n" . $contract . "\n";
         }

         $self->code($contract . substr($code, $defn_start));
      }
   }
}

sub to_string
{
   my $str      = '';
   my $code     = $_[0]->code;
   my $comments = $_[1];
   #my $remove_fields = $_[2];
   my $full = $_[3];

   my @cmnt = $code =~ m/$comment_t{pattern}/g;

   #crop to first spec comment
   # my $prior = index($code, '{');
   #foreach (@cmnt) {
   #   if (is_acsl_spec($comments->[$_])) {
   #      my $pos = index($code, $comment_t{L} . $_ . $comment_t{R});
   #      $code = substr($code, $pos)
   #        if $pos < $prior;
   #      goto FW_DECL;
   #   }
   #}
   # remove all comments since there is no specification binded to function
   # note that specification in function will be removed since they have no
   # meaning
   #$code =~ s/^${s}++//;
   #
   # FW_DECL:

   unless ($full) {
      my $prior = rindex(substr($code, 0, index($code, '{')), ')') + 1;
      $code = (substr($code, 0, $prior) =~ s/\s++\Z//r) . ';';
   } else {
      my $fw_decl = $_[0]->forward_declaration;
      if (@$fw_decl) {
         $str = join("\n", @$fw_decl) . "\n\n";
      }
   }

   $str .= $code;
}

__PACKAGE__->meta->make_immutable;

1;
