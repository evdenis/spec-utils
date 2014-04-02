package C::Function;
use Moose;

use Local::C::Parsing qw(_argname_exists);
use C::Keywords qw(@keywords_to_filter);
use Local::C::Transformation qw(:RE);
use Local::List::Utils qw(difference);
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

has 'get_code_tags' => (
   is => 'ro',
   isa => 'ArrayRef[Str]',
   lazy => 1,
   builder => '_build_code_tags',
   init_arg => undef
);


sub _build_code_tags
{
   my $self = shift;
   my $code = $self->code;

   my @list = ($code =~ m/\b[a-zA-Z_]\w*+\b/g);

   my $begin = index($code, '(') + 1;
   $code =~ m/\)${s}*+\{/;
   my $end = $-[0];
   $code = substr($code, $begin, $end - $begin);

   my @args;
   if ($code !~ m/\A${s}*+(?:void)?${s}*+\z/) {
      foreach(split(/,/, $code)) {
         next if m/\A${s}*+\z/;

         push @args, _argname_exists($_)
      }
   }

   my $filter = $self->get_code_ids();
   push @$filter, @keywords_to_filter;
   push @$filter, @args;

   [ difference(\@list, $filter) ]
}

sub to_string
{
   my $str;

   $str = join("\n", @{ $_[0]->forward_declaration }) . "\n\n";
   $str .= $_[0]->code;

   $str
}


__PACKAGE__->meta->make_immutable;

1;
