package C::Function;
use Moose;

use Local::C::Parsing qw(_argname_exists);
use C::Keywords qw(prepare_tags);
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

has [qw/ret args body/] => (
   is => 'ro',
   isa => 'Str',
   required => 1
);


sub get_code_tags
{
   my $self = shift;
   my $code = $self->code;

   my $begin = index($code, '(') + 1;
   $code =~ m/\)${s}*+\{/;
   my $end = $-[0];
   $code = substr($code, $begin, $end - $begin);

   my @args;
   if ($code !~ m/\A${s}*+(?:void)?${s}*+\z/) {
      foreach(split(/,/, $code)) {
         next if m/\A${s}*+(?:\.{3}${s}*+)?\z/;

         push @args, _argname_exists($_)
      }
   }

   my $filter = $self->get_code_ids();
   push @$filter, @args;

   prepare_tags($self->code, $filter)
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
