package Local::Kernel::Module::Graph;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use Graph::Directed;
use Graph::Reader::Dot;
use Scalar::Util qw(blessed);
use File::Slurp qw(write_file);

use Local::List::Utils qw(any);
use Local::C::Transformation qw(restore);

use constant HASH => ref {};
use constant ARRAY => ref [];

our @EXPORT_OK = qw(build_sources_graph get_predecessors_subgraph get_successors_subgraph output_sources_graph);


#dependency graph
my $dg = Graph::Reader::Dot->new()->read_graph(\*Local::Kernel::Module::Graph::DATA);


sub _dependencies_graph_iterator
{
   my $sources = shift;
   my @vertices = $dg->vertices;
   my $l = $#vertices;

   return sub {
      NEXT:
         return undef if $l < 0;
         my @keys = split /_/, $vertices[$l--];
         my $set = $sources->{$keys[0]}{$keys[1]};
         goto NEXT unless $set;

         return $set;
   };
}

#\%sources
sub __add_vertices
{
   my ($graph, $sources, $vname) = @_;

   my $next = _dependencies_graph_iterator($sources);
   while (my $set = $next->()) {
      $set = $set->set;
      foreach (@$set) {
         my $id = $_->$vname;

         if (!$graph->has_vertex($id)) {
            $graph->add_vertex($id);
            $graph->set_vertex_attributes($id, { object => $_ });
         } else {
            die("Internal Error. Vertex has been already added to the graph");
         }
      }
   }
}

sub _norm
{
   $_[0] =~ s/\s++//gr
}

sub _build_ids_index
{
   my %index;

   my $next = _dependencies_graph_iterator($_[0]);
   while (my $set = $next->()) {
      my $ids = $set->ids();
      while ( my ($i, $id) = each @{$ids} ) {
         my @id = @{$id};

         foreach (@id) {
            if (exists $index{$_}) {
RECHECK:
               my $o  = $index{$_};
               my $to = ref $o;

               if ($to eq HASH ) {
                  my $n  = $set->get_from_index($i);
                  my $tn = blessed($n);

                  unless (exists $index{$_}{$tn}) {
                     $index{$_}{$tn} = $n
                  } elsif ($index{$_}{$tn} == $n) {
                  } elsif (($tn eq 'C::Macro') || ($tn eq 'C::Typedef')) {
                     unless (_norm($index{$_}{$tn}->code) eq _norm($n->code)) {
                        warn("$tn '" . $n->name . "' redefinition\n");
                        $index{$_}{$tn} = $n if ($index{$_}{$tn}->area eq 'kernel') && ($n->area eq 'module')
                     }
                  } else {
                     die("Internal error: $tn duplicate. ID: $_")
                  }
               } else {
                  $index{$_} = {};
                  $index{$_}{$to} = $o;
                  goto RECHECK;
               }
            } else {
               $index{$_} = $set->get_from_index($i);
            }
         }
      }
   }

   \%index
}


sub __to_vertex
{
   $_[0]->area . '_' . lcfirst(substr(blessed($_[0]), 3))
}

#label type
sub _allow
{
   $_[1] eq 'C::Macro'
   ||
   $_[0] eq 'enum' && ($_[1] eq 'C::Enum' || $_[1] eq 'C::Typedef')
   ||
   ($_[0] eq 'struct' || $_[0] eq 'union') && ($_[1] eq 'C::Structure' || $_[1] eq 'C::Typedef')
}



my %__sort_priority = (
   'C::Macro'     => 1,
   'C::Structure' => 2,
   'C::Enum'      => 3,
   'C::Typedef'   => 4,
);
sub __sort_cmp
{
   my $pa = $__sort_priority{blessed($a)} // 10;
   my $pb = $__sort_priority{blessed($b)} // 10;
   $pa <=> $pb
}


sub _create_edges
{
   my ($index, $to, $label, $graph, $vname, $order) = @_;
   
   my @possible;
   foreach (keys %$index) {
      push @possible, $index->{$_}
         if $dg->has_edge(__to_vertex($index->{$_}), __to_vertex($to))
   }
   die('Can\'t find object of appropriate type' . blessed($to) . ' for ' . $to->name)
      unless @possible;

   @possible = sort __sort_cmp @possible;

   my @from;
   #only one instance of type possible
   my $legal = 0;
   foreach (@possible) {
      my $type = blessed($_);
      if ($label) {
         if (_allow($label, $type)) {
            push @from, $_;
            $legal = 1;
            last
         }
      } else {
         if ($type eq 'C::Macro') {
            push @from, $_;
            $legal = 1;
            last
         }
         # Should bind them anyway
         #if ($t eq 'C::Structure' || $t eq 'C::Enum') {
         #   use Data::Dumper;
         #   print Dumper $_;
         #   print Dumper $to;
         #   die('Internal error')
         #}
      }

      #bind with all
      push @from, $_;
   }

   if ($legal && @from == 1) {
      $graph->add_edge($order->($from[0]->$vname, $to->$vname))
   } elsif (!$legal && $label) {
      die('Internal error')
   } elsif (!$legal && !$label) {
      foreach(@from) {
         $graph->add_edge($order->($_->$vname, $to->$vname))
      }
   }
}

#human_readable:
# by default uniq ids are used as vertex names
# hr option will force use of original names of
# entities, but in this case duplicates are
# possible, which will lead to errors in graph.
# This option should be used carefully.
sub build_sources_graph
{
   my ($sources, $human_readable, $reverse) = @_;

   my $vname = 'id'; #method for vertex name generation
   $vname = 'name'
      if $human_readable;

   my $order;
   if ($reverse) {
      $order = sub { ($_[1], $_[0]) }
   } else {
      $order = sub { @_ }
   }

   my $graph = Graph::Directed->new();
   my $index = _build_ids_index($sources);

   __add_vertices($graph, $sources, $vname);

   my $next = _dependencies_graph_iterator($sources);
   while (my $set = $next->()) {
      print "TAGS: " . blessed($set) ."\n";

      my $tags = $set->tags();
      while (my ($i, $t) = each @{$tags}) {
         foreach my $tag (@{$t}) {
            my $label;

            ($label, $tag) = @$tag
               if ref $tag eq ARRAY;

            if (exists $index->{$tag}) {
               my $from = $index->{$tag};
               my $to = $set->get_from_index($i);
            
               if (ref $from eq HASH) {
                  _create_edges($from, $to, $label, $graph, $vname, $order)
               } else {
                  if ($dg->has_edge(__to_vertex($from), __to_vertex($to))) {
                     if ($label) {
                        my $type = blessed($from);

                        die("Wrong type: want $label, but get $type. Objects:\n" . $from->code . "\n<->\n" . $to->code)
                           unless _allow($label, $type);
                     }

                     $graph->add_edge($order->($from->$vname, $to->$vname))
                  }
               }
            }
         }
      }
   }

   $graph
}


sub _generic_get_subgraph
{
   my ($graph, $id, $method) = @_;

   my @pr = $graph->$method($id);
   push @pr, $id;

   my $subgraph =
      Graph::Directed->new(edges =>
         [ grep { any($_->[0], \@pr) && any($_->[1], \@pr) } $graph->edges ]
      );

   $subgraph->set_vertex_attributes($_, $graph->get_vertex_attributes($_))
      foreach @pr;

   $subgraph->set_graph_attribute('comments', $graph->get_graph_attribute('comments'))
      if $graph->has_graph_attribute('comments');

   $subgraph

}

sub get_predecessors_subgraph
{
   _generic_get_subgraph(@_, 'all_predecessors')
}

sub get_successors_subgraph
{
   _generic_get_subgraph(@_, 'all_successors')
}


sub _write_to_files
{
   my ($output_dir, $single_file, $content) = @_;

   my $module_c = 'parsec.c';
   my $module_h = 'module.h';
   my $kernel_h = 'kernel.h';
   my $extern_h = 'extern.h';

   $module_c = "$output_dir/$module_c"
      if $output_dir;

   if ($single_file) {
      write_file($module_c, join("\n" . '//' . '-' x 78 . "\n\n",
                                 (
                                   $content->{kernel_h},
                                   $content->{extern_h},
                                   $content->{module_h},
                                   $content->{module_c}
                                 )
                            )
                );
   } else {

      $content->{module_c} =
         qq(#include "$kernel_h"\n#include "$extern_h"\n#include "$module_h"\n\n) .
         $content->{module_c};

      if ($output_dir) {
         $module_h = "$output_dir/$module_h";
         $kernel_h = "$output_dir/$kernel_h";
         $extern_h = "$output_dir/$extern_h";
      }

      write_file($module_c, $content->{module_c});
      write_file($module_h, $content->{module_h});
      write_file($kernel_h, $content->{kernel_h});
      write_file($extern_h, $content->{extern_h});
   }
}


my %sp = (
             'C::Enum'      => 2,
             'C::Typedef'   => 3,
             'C::Structure' => 4,

             'C::Macro'       => 1,
             'C::Global'      => 5,
             'C::Declaration' => 6,
             'C::Function'    => 7
         );

sub output_sources_graph
{
   my ($graph, $output_dir, $single_file) = @_;

   my $module_c_content = '';
   my $module_h_content = '';
   my $kernel_h_content = '';
   my $extern_h_content = '';
   my $kernel_macro = '';
   my $module_macro = '';

   my %vertices = map { ($_ => 0) } $graph->vertices;

   while (keys %vertices) {
      my @zv;
      foreach(keys %vertices) {
         push @zv, $_ unless $graph->in_degree($_);
      }

      die("Cycle in graph") unless @zv;

      delete $vertices{$_} foreach @zv;


      my %i = map {
                     my $o = $graph->get_vertex_attribute($_, 'object');
                     ($_ => {
                           object => $o,
                           type => blessed($o),
                           area => $o->area
                        })
                  } @zv;

      my $sort_sub = sub {
            $sp{$i{$a}->{type}} <=> $sp{$i{$b}->{type}}
         or
            $i{$a}->{object}->name cmp $i{$b}->{object}->name
      };

      foreach (sort $sort_sub keys %i) {
         my $o = $i{$_}->{object};
         my $a = $i{$_}->{area};
         my $t = $i{$_}->{type};
         my $content;

         if ($a eq 'kernel') {
            if ($t eq 'C::Declaration' || $t eq 'C::Global') {
               $content = \$extern_h_content
            } elsif ($t eq 'C::Macro') {
               $content = \$kernel_macro
            } else {
               $content = \$kernel_h_content
            }
         } else {
            if ($t eq 'C::Function') {
               $content = \$module_c_content
            } elsif ($t eq 'C::Macro') {
               $content = \$module_macro
            } else {
               $content = \$module_h_content
            }
         }

         $$content .= $o->to_string . "\n\n";
      }

      $graph->delete_vertices(@zv);
   }

   $module_h_content = $module_macro . $module_h_content;
   $kernel_h_content = $kernel_macro . $kernel_h_content;

   {
      my $c = $graph->get_graph_attribute('comments');

      foreach ($module_macro, $module_h_content, $module_c_content) {
         restore($_, comments => $c)
      }
   }

   _write_to_files(
      $output_dir,
      $single_file,
      {
         kernel_h => $kernel_h_content,
         extern_h => $extern_h_content,
         module_h => $module_h_content,
         module_c => $module_c_content
      }
   )
}

1;

__DATA__
digraph g
{
   subgraph cluster_kernel {
      kernel_macro;
      kernel_structure;
      kernel_declaration;
      kernel_typedef;
      kernel_enum;
      kernel_global;

      // kernel_macro; nothing already preprocessed
      kernel_macro -> kernel_macro;

      kernel_structure -> kernel_macro;
      kernel_structure -> kernel_structure;
      kernel_structure -> kernel_declaration;
      kernel_structure -> kernel_typedef;
      kernel_structure -> kernel_enum; //sizeof
      kernel_structure -> kernel_global;

      kernel_declaration -> kernel_macro;

      kernel_typedef -> kernel_macro;
      kernel_typedef -> kernel_structure;
      kernel_typedef -> kernel_declaration;
      kernel_typedef -> kernel_typedef;
      kernel_typedef -> kernel_enum;
      kernel_typedef -> kernel_global;

      kernel_enum -> kernel_macro;
      kernel_enum -> kernel_structure;
      kernel_enum -> kernel_declaration;
      kernel_enum -> kernel_typedef;
      kernel_enum -> kernel_enum;
      kernel_enum -> kernel_global;

      kernel_global -> kernel_macro;
   }

   subgraph cluster_module {
      module_macro;
      module_structure;
      module_function;
      module_typedef;
      module_enum;
      module_global;

      module_macro -> module_macro;
      module_macro -> module_structure;
      module_macro -> module_function;
      module_macro -> module_typedef;
      module_macro -> module_enum;
      module_macro -> module_global;
      //
      kernel_macro -> module_macro;
      kernel_macro -> module_structure;
      kernel_macro -> module_function;
      kernel_macro -> module_typedef;
      kernel_macro -> module_enum;
      kernel_macro -> module_global;

      module_structure -> module_macro;
      module_structure -> module_structure;
      module_structure -> module_function;
      module_structure -> module_typedef;
      module_structure -> module_enum; //sizeof
      module_structure -> module_global;
      //
      kernel_structure -> module_macro;
      kernel_structure -> module_structure;
      kernel_structure -> module_function;
      kernel_structure -> module_typedef;
      kernel_structure -> module_enum; //sizeof
      kernel_structure -> module_global;

      module_function -> module_macro;
      module_function -> module_function;
      //
      kernel_declaration -> module_macro;
      kernel_declaration -> module_function;

      module_typedef -> module_macro;
      module_typedef -> module_structure;
      module_typedef -> module_function;
      module_typedef -> module_typedef;
      module_typedef -> module_enum;
      module_typedef -> module_global;
      //
      kernel_typedef -> module_macro;
      kernel_typedef -> module_structure;
      kernel_typedef -> module_function;
      kernel_typedef -> module_typedef;
      kernel_typedef -> module_enum;
      kernel_typedef -> module_global;

      module_enum -> module_macro;
      module_enum -> module_structure;
      module_enum -> module_function;
      module_enum -> module_typedef;
      module_enum -> module_enum;
      module_enum -> module_global;
      //
      kernel_enum -> module_macro;
      kernel_enum -> module_structure;
      kernel_enum -> module_function;
      kernel_enum -> module_typedef;
      kernel_enum -> module_enum;
      kernel_enum -> module_global;

      module_global -> module_macro;
      module_global -> module_function;
      //
      kernel_global -> module_macro;
      kernel_global -> module_function;
   }
}

