package C::Function;
use namespace::autoclean;
use Moose;

use re '/aa';
use Local::C::Parse qw(@keywords _argname_exists);
use Local::C::Transformation qw(:RE);
use Local::List::Utils qw(difference);

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

   my @list = ($code =~ m/\b[a-zA-Z_]\w*\b/g);

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
   push @$filter, @keywords;
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
