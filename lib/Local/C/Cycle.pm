package Local::C::Cycle;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);
use Scalar::Util qw(blessed);
use Local::C::Transformation qw(:RE);
use Local::String::Utils qw(normalize);

our @EXPORT = qw/resolve/;

sub resolve_macro_macro ($$$)
{
   my ($graph, @obj) = @_;
   my @name  = map $_->name, @obj;

   # errors in binding
   #if ($obj[0]->args) {
   #   if ($obj[1]->code !~ m/\b$name[0]\s*+\(/) {
   #      $g->delete_edge($obj[0]->id, $obj[1]->id)
   #   }
   #}
   #if ($obj[1]->args) {
   #   if ($obj[0]->code !~ m/\b$name[1]\s*+\(/) {
   #      $g->delete_edge($obj[1]->id, $obj[0]->id)
   #   }
   #}
   
   $graph->delete_edge($obj[0]->id, $obj[1]->id);

   1
}

sub resolve_structure_structure ($$$)
{
   my ($graph, @obj) = @_;
   my @ctype = map $_->type, @obj;
   my @name  = map $_->name, @obj;

   ## 0 -> 1 exists; checking for reverse dependency
   #if ($graph->has_edge($obj[1]->id, $obj[0]->id)) {
   #   # 0 -> 1
   #   if ($obj[1]->code =~ m/$ctype[0]${s}*+$name[0]${s}*+\*/) {
   #      $graph->delete_edge($obj[0]->id, $obj[1]->id)
   #      return 1
   #   }
   #   # 1 -> 0; overstatement
   #   if ($obj[0]->code =~ m/$ctype[1]${s}*+$name[1]${s}*+\*/) {
   #      $graph->delete_edge($obj[1]->id, $obj[0]->id)
   #      return 1
   #   }
   #}

   if ($obj[1]->code =~ m/$ctype[0]${s}++$name[0]${s}*+\*/) {
      $graph->delete_edge($obj[0]->id, $obj[1]->id);
      return 1
   }

   0
}

sub resolve_function_function
{
   my ($graph, @obj) = @_;
   my @ctype = map $_->type, @obj;
   my @name  = map $_->name, @obj;

   $obj[1]->code =~ m/(\w.*?)\{/s;
   $obj[0]->add_fw_decl(normalize($1) . ';');

   $graph->delete_edge($obj[0]->id, $obj[1]->id);

   1
}

sub resolve_structure_typedef ($$$)
{
   my ($graph, @obj) = @_;

   $graph->delete_edge($obj[0]->id, $obj[1]->id);

   1
}

sub resolve_typedef_structure
{
   0
}


sub resolve
{
   my ($graph, @cycle) = @_;

   if (@cycle == 1) {
      $graph->delete_edge(@cycle[0,0])
   } else {
      my @objs = map { $graph->get_vertex_attribute($_, 'object') } @cycle;
      my @obj_pairs;
      {
         my $prev = $objs[-1];
         foreach (@objs) {
            push @obj_pairs, [$prev, $_];
            $prev = $_;
         }
      }

      my $ok = 0;
      foreach (@obj_pairs) {
         my @t   = map blessed $_, @$_;

         my $trans = sub { lc(substr($_[0], 3)) };
         my $sub = join('_', ('resolve', $trans->($t[0]), $trans->($t[1])));

         {
            no strict 'refs';

            if (defined &{ $sub }) {
               $ok = 1, last if
                  &{ $sub }($graph, @$_)
            } else {
               warn "Function $sub in Local::C::Cycle package doesn't exist. Skipping the call.\n";
            }
         }
      }

      unless ($ok) {
         warn "Can't properly resolve cycle.\n";
         $graph->delete_edge(@cycle[0,-1])
      }
   }
}

1;
