package Kernel::Module::Graph;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

use Graph::Directed;
use Graph::Reader::Dot;
use Scalar::Util qw(blessed);
use File::Slurp qw(write_file);
use Storable qw(store retrieve);
use File::Spec::Functions qw(catfile);

use Local::List::Util qw(any);
use Local::String::Util qw(eq_spaces);
use C::Util::Transformation qw(restore);
use C::Util::Cycle qw(resolve);

use constant HASH  => ref {};
use constant ARRAY => ref [];

our @EXPORT_OK = qw(
  build_sources_graph
  get_predecessors_subgraph
  get_successors_subgraph
  get_strict_predecessors_subgraph
  get_strict_successors_subgraph
  output_sources_graph
  get_isolated_subgraph
  %out_file
  @out_order
);

our %out_file = (
   module_c => undef,
   module_h => undef,
   kernel_h => undef,
   extern_h => undef,
);

our @out_order = ('kernel_h', 'extern_h', 'module_h', 'module_c',);

my %_order  = (0 => sub {@_}, 1 => sub {($_[1], $_[0])});
my $_orderp = 0;
my ($order, $vname);

sub init
{
   my $opts = (ref $_[0] eq HASH) ? shift : {@_};
   $opts->{reverse}        ||= 0;
   $opts->{human_readable} ||= 0;

   $vname = $opts->{human_readable} ? 'name' : 'id';

   $_orderp = $opts->{reverse};
   $order   = $_order{$_orderp};

   0;
}

init();

#dependency graph
my $dg = Graph::Reader::Dot->new()->read_graph(\*Kernel::Module::Graph::DATA);

sub __dependencies_graph_iterator_generic
{
   my $sources     = shift;
   my @vertices    = @_ ? grep {m/$_[0]/} $dg->vertices : $dg->vertices;
   my $l           = $#vertices;
   my %_sort_order = (
      macro       => 1,
      enum        => 2,
      structure   => 3,
      typedef     => 4,
      declaration => 5,
      global      => 6,
      function    => 7,
      acslcomment => 8
   );

   # Strict order
   # reverse because of vertices[$l--]
   @vertices = reverse sort {$_sort_order{(split /_/, $a)[1]} <=> $_sort_order{(split /_/, $b)[1]}} @vertices;

   return sub {
    NEXT:
      return undef if $l < 0;
      my @keys = split /_/, $vertices[$l--];
      my $set  = $sources->{$keys[0]}{$keys[1]};
      goto NEXT unless $set;

      return $set;
   };
}

sub _dependencies_graph_iterator
{
   goto &__dependencies_graph_iterator_generic;
}

sub _dependencies_graph_iterator_kernel
{
   push @_, qr/\Akernel_/;
   goto &__dependencies_graph_iterator_generic;
}

sub _dependencies_graph_iterator_module
{
   push @_, qr/\Amodule_/;
   goto &__dependencies_graph_iterator_generic;
}

#\%sources
sub __add_vertices
{
   my ($graph, $iterator) = @_;

   while (my $set = $iterator->()) {
      $set = $set->set;
      foreach (@$set) {
         my $id = $_->$vname;

         unless ($graph->has_vertex($id)) {
            $graph->add_vertex($id);
            $graph->set_vertex_attributes($id, {object => $_});
         } else {
            die("Internal Error. Vertex has been already added to the graph: " . $_->name);
         }
      }
   }
}

sub _update_ids_index
{
   my %index    = %{$_[0]};
   my $iterator = $_[1];
   my $comments = $_[2];

   while (my $set = $iterator->()) {
      my $ids = $set->ids();
      while (my ($i, $id) = each @{$ids}) {
         my @id = @{$id};

         foreach (@id) {
            if (exists $index{$_}) {
             RECHECK:
               my $o  = $index{$_};
               my $to = ref $o;

               if ($to eq HASH) {
                  my $n  = $set->get_from_index($i);
                  my $tn = blessed($n);

                  #declaration <-> function handling
                  if ($tn eq 'C::Declaration') {
                     if (exists $index{$_}{'C::Function'}) {
                        if ($n->spec_ids()) {
                           $index{$_}{'C::Function'}->attach_declaration($n, $comments);
                        }
                        next;
                     }
                  } elsif ($tn eq 'C::Function') {
                     if (exists $index{$_}{'C::Declaration'}) {
                        my $decl = $index{$_}{'C::Declaration'};
                        if ($decl->spec_ids()) {
                           $n->attach_declaration($decl, $comments);
                           # Just in case
                           # $decl->remove_contract();
                        }
                        delete $index{$_}{'C::Declaration'};
                     }
                  }

                  unless (exists $index{$_}{$tn}) {
                     $index{$_}{$tn} = $n;
                  } elsif ($index{$_}{$tn} == $n) {
                  } elsif (($tn eq 'C::Macro') || ($tn eq 'C::Typedef')) {
                     unless (eq_spaces($index{$_}{$tn}->code, $n->code)) {
                        warn("$tn '" . $n->name . "' redefinition\n");
                        $index{$_}{$tn} = $n if ($index{$_}{$tn}->area eq 'kernel') && ($n->area eq 'module');
                     }
                  } elsif ($tn eq 'C::Acslcomment') {
                     $index{$_}{$tn} = [$index{$_}{$tn}];
                     push @{$index{$_}{$tn}}, $n;
                  } elsif ($tn eq 'C::Global') {
                     my ($old, $new) = ($index{$_}{$tn}, $n);
                     my $die = 1;

                     unless (eq_spaces($old->type, $new->type)) {
                        warn "$tn type conflict. Trying to resolve...\n";
                        # Checking for 'typedef struct name1 {} name2'
                        if ($old->type =~ m/\bstruct\b/ || $new->type =~ m/\bstruct\b/) {
                           # FIXME: const
                           my @old_type_words = ($old->type =~ m/\w++/g);
                           my @new_type_words = ($old->type =~ m/\w++/g);
                           my $old_type_id = $#old_type_words > 1 ? $old_type_words[1] : $old_type_words[0];
                           my $new_type_id = $#new_type_words > 1 ? $new_type_words[1] : $new_type_words[0];
                           my $type_old    = 1;
                           my $type_new    = 2;

                           $type_old = $index{$old_type_id}
                             if exists $index{$old_type_id};
                           $type_new = $index{$new_type_id}
                             if exists $index{$new_type_id};

                           if ($type_old == $type_new && defined $type_old) {
                              warn "Resolved.\n";
                              $die = 0;
                           }
                        }

                        if ($die) {
                           die(   "Internal error: $tn duplicate. ID: $_.\n"
                                . "Globals have different types: "
                                . $new->type . ", "
                                . $old->type
                                . "\n");
                        }
                     } else {
                        if ($old->initialized && $new->initialized) {
                           if ($old->initializer ne $new->initializer) {
                              die "Globals duplicate with different initialization: $_\n";
                           }
                        }
                        if (  ($new->initialized && !$old->initialized)
                           || (!$new->extern && $old->extern))
                        {
                           $index{$_}{$tn} = $new;
                        }
                     }
                  } elsif ($tn eq 'C::Declaration') {
                     if (($index{$_}{$tn}->area eq 'kernel') && ($n->area eq 'module')) {
                        $index{$_}{$tn} = $n;
                     }
                  } else {
                     #print $index{$_}{$tn}->code . "\n";
                     #print $n->code . "\n";
                     die("Internal error: $tn duplicate. ID: $_\n");
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

   \%index;
}

my %___to_vertex = (
   'C::Macro'       => 'macro',
   'C::Structure'   => 'structure',
   'C::Enum'        => 'enum',
   'C::Typedef'     => 'typedef',
   'C::Acslcomment' => 'acslcomment',
   'C::Declaration' => 'declaration',
   'C::Global'      => 'global',
   'C::Function'    => 'function'
);

sub __to_edge
{
   my $v1 = blessed($_[0]);
   my $v2 = blessed($_[1]);

   $v2 = 'C::Function'
     if $v2 eq 'C::Acslcomment' && $_[1]->is_ghost;

   return ($_[0]->area . '_' . $___to_vertex{$v1}, $_[1]->area . '_' . $___to_vertex{$v2});
}

#label type
sub _allow
{
   $_[1] eq 'C::Macro'
     || $_[0] eq 'enum' && ($_[1] eq 'C::Enum' || $_[1] eq 'C::Typedef')
     || ($_[0] eq 'struct' || $_[0] eq 'union') && ($_[1] eq 'C::Structure' || $_[1] eq 'C::Typedef');
}

my %__sort_priority = (
   'C::Macro'       => 1,
   'C::Structure'   => 2,
   'C::Enum'        => 3,
   'C::Typedef'     => 4,
   'C::Acslcomment' => 5,
);

sub __sort_cmp
{
   my $pa = $__sort_priority{blessed($a)} // 10;
   my $pb = $__sort_priority{blessed($b)} // 10;
   $pa <=> $pb;
}

sub __add_edge
{
   if (blessed($_[1]) eq 'C::Enum') {
      $_[1]->up($_[3]);
   }
   $_[0]->add_edge($order->($_[1]->$vname, $_[2]->$vname));
}

sub _create_edges
{
   my ($graph, $index, $to, $label, $tag) = @_;

   my @possible;
   {
      my @keys = keys %$index;
      return if @keys == 0;

      foreach (@keys) {
         if (ref $index->{$_} eq ARRAY) {
            if ($dg->has_edge(__to_edge($index->{$_}[0], $to))) {
               push @possible, @{$index->{$_}};
            }
         } else {
            if ($dg->has_edge(__to_edge($index->{$_}, $to))) {
               push @possible, $index->{$_};
            }
         }
      }
      return
        unless @possible;
   }

   @possible = sort __sort_cmp @possible;

   my @from;
   #only one instance of type possible
   my $single = 0;
   foreach (@possible) {
      my $type = blessed($_);
      if ($label) {
         if (_allow($label, $type)) {
            push @from, $_;
            $single = 1;
            last;
         }
      } else {
         if ($type eq 'C::Macro') {
            push @from, $_;
            unless ($_->expands_to_itself) {
               $single = 1;
               last;
            }
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

   if ($single && @from == 1) {
      __add_edge($graph, $from[0], $to, $tag);
   } elsif (!$single && $label) {
      die('Internal error');
   } elsif (!$single && !$label) {
      foreach (@from) {
         __add_edge($graph, $_, $to, $tag);
      }
   }
}

sub _form_graph
{
   my ($graph, $index, $iterator) = @_;

   while (my $set = $iterator->()) {
      print "TAGS: " . blessed($set) . "\n";

      my $tags = $set->tags();
      while (my ($i, $t) = each @{$tags}) {
         foreach my $tag (@{$t}) {
            my $label;

            ($label, $tag) = @$tag
              if ref $tag eq ARRAY;

            if (exists $index->{$tag}) {
               my $from = $index->{$tag};
               my $to   = $set->get_from_index($i);

               if (ref $from eq HASH) {
                  _create_edges($graph, $from, $to, $label, $tag);
               } else {
                  if ($dg->has_edge(__to_edge($from, $to))) {
                     if ($label) {
                        my $type = blessed($from);

                        unless (_allow($label, $type)) {
                           warn(  "Wrong type: want $label, but get $type."
                                . "Objects:\n"
                                . $from->code
                                . "\n<->\n"
                                . $to->code)
                             if $ENV{DEBUG};
                           next;
                        }
                     }

                     __add_edge($graph, $from, $to, $tag);
                  }
               }
            } else {
               warn "Can't bind tag: $tag\n" if $ENV{DEBUG};
            }
         }
      }
   }

   $graph;
}

#human_readable:
# by default uniq ids are used as vertex names
# hr option will force use of original names of
# entities, but in this case duplicates are
# possible, which will lead to errors in graph.
# This option should be used carefully.
sub build_sources_graph
{
   my $sources = shift;
   my $opts    = (ref $_[0] eq HASH) ? shift : {@_};

   my $index;
   if ($opts->{cache}{use}) {
      my ($hr, $rev);
      my ($k,  $ks);
      ($index, $k, $ks, $hr, $rev) = @{retrieve($opts->{cache}{file})};
      die("Internal error. Corrupted cache.\n")
        unless $hr eq $vname && $rev == $_orderp;

      $sources->{kernel}         = $k;
      $sources->{kernel_strings} = $ks;
   } else {
      $index = _update_ids_index({}, _dependencies_graph_iterator_kernel($sources), undef);

      store([$index, $sources->{kernel}, $sources->{kernel_strings}, $vname, $_orderp], $opts->{cache}{file})
        if $opts->{cache}{file};
   }

   my %specs;
   my %spec_index;
   %spec_index = $sources->{module}{acslcomment}->map(
      sub {
         my $id = $_->replacement_id;
         $specs{$id} = $_->code;
         return ($id => $_);
      }
   );
   $index = _update_ids_index($index, _dependencies_graph_iterator_module($sources), \%specs);

   my $graph = Graph::Directed->new();
   __add_vertices($graph, _dependencies_graph_iterator_kernel($sources));
   __add_vertices($graph, _dependencies_graph_iterator_module($sources));

   $graph = _form_graph($graph, $index, _dependencies_graph_iterator_kernel($sources));

   $graph = _form_graph($graph, $index, _dependencies_graph_iterator_module($sources));

   if (%specs) {
      # ACSL handling specs to functions edge
      foreach (@{$sources->{module}{function}->set}, @{$sources->{module}{declaration}->set}) {
         foreach my $id (@{$_->spec_ids}) {
            if (exists $spec_index{$id}) {
               unless ($_->can_detach_specification($id, $spec_index{$id}->code)) {
                  $spec_index{$id}->function_spec($_->id);
                  $graph->add_edge($spec_index{$id}->id, $_->id);
               } else {
                  $_->detach_specification($id);
               }
            }
         }
      }

      # functions dependence by specs
      foreach ($graph->edges) {
         my $v1 = $graph->get_vertex_attribute($_->[0], 'object');
         my $v2 = $graph->get_vertex_attribute($_->[1], 'object');

         if (blessed($v1) eq 'C::Acslcomment' && blessed($v2) eq 'C::Acslcomment') {
            if ($v1->function_spec && $v2->function_spec) {
               $graph->delete_edge($v1->id, $v2->id);
               my @fids = ($v1->function_spec, $v2->function_spec);
               if (!$graph->has_edge(@fids)) {
                  $graph->add_edge(@fids);
                  $graph->set_edge_attribute(@fids, spec_edge => 1);
               }
            }
         }
      }
   }

   $graph;
}

my %ft  = (all_predecessors => 'edges_to',   all_successors => 'edges_from');
my %rft = (all_predecessors => 'edges_from', all_successors => 'edges_to');     # reverse

sub _generic_get_subgraph
{
   my ($method, $strict, $graph, @id) = @_;
   my $em            = $ft{$method};
   my $me            = $rft{$method};
   my $from_edge_gen = sub {
      $_[0] eq 'edges_from' ? sub {$_->[1]} : sub {$_->[0]};
   };
   my $from_em_edge = $from_edge_gen->($em);
   my $from_me_edge = $from_edge_gen->($me);

   my @pr;
   my $subgraph;

   if ($strict) {
      @pr = @id;
      my @queue = @id;
      while (my $v = shift @queue) {
         my @vs = map $from_em_edge->($_), $graph->$em($v);
         my @sv;

         foreach (@vs) {
            my $all = 1;
            foreach (map $from_me_edge->($_), $graph->$me($_)) {
               if (!any($_, @pr)) {
                  $all = 0;
                  last;
               }
            }
            push @sv, $_
              if $all;
         }

         push @queue, @sv;
         push @pr,    @sv;
      }

      $subgraph = Graph::Directed->new(vertices => [@pr]);
      my %pr;
      @pr{@pr} = undef;
      $subgraph->add_edges(grep {exists $pr{$_->[0]} && exists $pr{$_->[1]}} $graph->edges);
   } else {
      @pr = (@id, $graph->$method(@id));
      $subgraph = Graph::Directed->new(edges => [map $graph->$em($_), @pr]);
   }

   $subgraph->set_vertex_attributes($_, $graph->get_vertex_attributes($_)) foreach @pr;

   $subgraph->set_edge_attributes(@$_, $graph->get_edge_attributes(@$_)) foreach $subgraph->edges;

   foreach (qw(comments module_strings kernel_strings)) {
      $subgraph->set_graph_attribute($_, $graph->get_graph_attribute($_))
        if $graph->has_graph_attribute($_);
   }

   $subgraph;
}

sub get_predecessors_subgraph
{
   _generic_get_subgraph('all_predecessors', 0, @_);
}

sub get_strict_predecessors_subgraph
{
   _generic_get_subgraph('all_predecessors', 1, @_);
}

sub get_successors_subgraph
{
   _generic_get_subgraph('all_successors', 0, @_);
}

sub get_strict_successors_subgraph
{
   _generic_get_subgraph('all_successors', 1, @_);
}

sub get_isolated_subgraph
{
   my $graph = $_[0];

   my $subgraph = Graph->new();
   my @vertices = $graph->isolated_vertices();

   $subgraph->add_vertices(@vertices);

   $subgraph->set_vertex_attributes($_, $graph->get_vertex_attributes($_)) foreach @vertices;

   $subgraph->set_graph_attribute('comments', $graph->get_graph_attribute('comments'))
     if $graph->has_graph_attribute('comments');

   $subgraph;
}

sub _write_to_files
{
   my ($output_dir, $output_file, $single_file, $content, $call) = @_;
   my @files;

   $out_file{$_} = $_ =~ s/_(?=[ch]\Z)/./r foreach keys %out_file;

   $out_file{module_c} = catfile $output_dir, $out_file{module_c}
     if $output_dir;

   if ($single_file == 1) {

      $out_file{module_h} = '';
      $out_file{kernel_h} = '';
      $out_file{extern_h} = '';

      if ($output_file) {
         $out_file{module_c} = catfile $output_dir, $output_file;
      }

      $call->(
         level      => 'raw_data',
         files      => \%out_file,
         output_dir => $output_dir,
         output     => $content
      );

      $call->(
         level      => 'pre_output',
         files      => \%out_file,
         output_dir => $output_dir,
         output     => $content
      );

      write_file($out_file{module_c}, join("\n" . '//' . '-' x 78 . "\n\n", map {$content->{$_} || ()} @out_order));
      push @files, $out_file{module_c};
   } elsif ($single_file == 2) {

      $out_file{kernel_h} = '';
      $out_file{extern_h} = '';

      my $output_h_file = $out_file{module_h};
      if ($output_file) {
         $out_file{module_c} = catfile $output_dir, $output_file;
         unless ($output_h_file = $output_file =~ s/\.c$/.h/r) {
            $output_h_file = "${output_file}.h";
         }
      }

      $call->(
         level      => 'raw_data',
         files      => \%out_file,
         output_dir => $output_dir,
         output     => $content
      );
      my %blank = map {$_ => ($content->{$_} ? 0 : 1)} keys %$content;

      if (!$blank{kernel_h} || !$blank{module_h} || !$blank{extern_h}) {
         $content->{module_h} =
           join("\n" . '//' . '-' x 78 . "\n\n", map {$blank{$_} ? () : $content->{$_}} grep {m/_h$/} @out_order);
         $content->{kernel_h} = undef;
         $content->{extern_h} = undef;

         my $define = uc($output_h_file);
         $define = $define =~ s/[^\w]/_/gr;
         $define = '__' . $define . '__';
         $content->{module_h} =
           qq(#ifndef $define\n#define $define\n\n) . $content->{module_h} . qq(\n\n#endif // $define);

         $content->{module_c} = qq(#include "$output_h_file"\n\n) . $content->{module_c};

         $out_file{module_h} = catfile $output_dir, $output_h_file
           if $output_dir;
      }

      $call->(
         level      => 'pre_output',
         files      => \%out_file,
         output_dir => $output_dir,
         output     => $content
      );

      if ($content->{module_h}) {
         write_file($out_file{module_h}, $content->{module_h});
         push @files, $out_file{module_h};
      }
      write_file($out_file{module_c}, $content->{module_c});
      push @files, $out_file{module_c};
   } else {

      warn "Can't write result to a single file $output_file. Will use default scheme with 4 files.\n"
        if $output_file;

      $call->(
         level      => 'raw_data',
         files      => \%out_file,
         output_dir => $output_dir,
         output     => $content
      );
      my %blank = map {$_ => ($content->{$_} ? 0 : 1)} keys %$content;

      unless ($blank{kernel_h}) {
         $content->{kernel_h} =
           qq(#ifndef __KERNEL_H__\n#define __KERNEL_H__\n\n) . $content->{kernel_h} . qq(\n\n#endif // __KERNEL_H__);
      }
      unless ($blank{extern_h}) {
         $content->{extern_h} =
             qq(#ifndef __EXTERN_H__\n#define __EXTERN_H__\n\n)
           . ($blank{kernel_h} ? '' : qq(#include "$out_file{kernel_h}"\n\n))
           . $content->{extern_h}
           . qq(\n\n#endif // __EXTERN_H__);
      }
      unless ($blank{module_h}) {
         $content->{module_h} =
             qq(#ifndef __MODULE_H__\n#define __MODULE_H__\n\n)
           . ($blank{kernel_h} ? '' : qq(#include "$out_file{kernel_h}"\n))
           . ($blank{extern_h} ? '' : qq(#include "$out_file{extern_h}"\n)) . "\n"
           . $content->{module_h}
           . qq(\n\n#endif // __MODULE_H__);
      }
      $content->{module_c} =
          ($blank{kernel_h} ? '' : qq(#include "$out_file{kernel_h}"\n))
        . ($blank{extern_h} ? '' : qq(#include "$out_file{extern_h}"\n))
        . ($blank{module_h} ? '' : qq(#include "$out_file{module_h}"\n)) . "\n"
        . $content->{module_c};

      if ($output_dir) {
         $out_file{module_h} = catfile $output_dir, $out_file{module_h};
         $out_file{kernel_h} = catfile $output_dir, $out_file{kernel_h};
         $out_file{extern_h} = catfile $output_dir, $out_file{extern_h};
      }

      $call->(
         level      => 'pre_output',
         files      => \%out_file,
         output_dir => $output_dir,
         output     => $content
      );
      # update
      %blank = map {$_ => ($content->{$_} ? 0 : 1)} keys %$content;

      foreach (keys %out_file) {
         unless ($blank{$_}) {
            write_file($out_file{$_}, $content->{$_});
            push @files, $out_file{$_};
         }
      }
   }

   @files;
}

my %sp = (
   'C::Enum'      => 2,
   'C::Typedef'   => 3,
   'C::Structure' => 4,

   'C::Macro'       => 1,
   'C::Global'      => 5,
   'C::Declaration' => 6,
   'C::Acslcomment' => 7,
   'C::Function'    => 8
);

sub output_sources_graph
{
   my ($graph, $ids, $output_dir, $output_file, $single_file, $remove_fields, $fullkernel, $full, $call) = @_;

   my %out = map {$_ => []} qw/
     kernel_h
     extern_h
     module_h
     module_c
     kernel_macro
     module_macro
     /;

   #my %debug;
   my %vertices = map {$_ => 1} $graph->vertices;
   #foreach my $v ($graph->vertices) {
   #   foreach my $e ($graph->edges_to($v)) {
   #      push @{$debug{$v}}, $graph->get_vertex_attribute($e->[0], 'object')->name;
   #   }
   #}

   while ($graph->has_a_cycle) {
      resolve($graph, $graph->find_a_cycle);
   }

   my %vd = map {($_, $graph->in_degree($_))} keys %vertices;
   while (%vertices) {
      my @zv;

      foreach (keys %vertices) {
         push @zv, $_ if 0 == $vd{$_};
      }

      die("Cycle in graph") unless @zv;

      foreach my $v (@zv) {
         foreach my $e ($graph->edges_from($v)) {
            --$vd{$e->[1]};
            #push @{$debug{$v}}, $graph->get_vertex_attribute($e->[1], 'object')->name;
         }
         delete $vertices{$v};
      }

      my %i = map {
         my $o = $graph->get_vertex_attribute($_, 'object');
         (
            $_ => {
               object => $o,
               type   => blessed($o),
               area   => $o->area
            }
         )
      } @zv;

      my $sort_sub = sub {
         ($sp{$i{$a}->{type}} <=> $sp{$i{$b}->{type}})
           || ($i{$a}->{object}->name cmp $i{$b}->{object}->name)
           || (($i{$a}->{object}->get_code_ids())[0] cmp($i{$b}->{object}->get_code_ids())[0]);
      };

      foreach (sort $sort_sub keys %i) {
         my $o = $i{$_}->{object};
         my $a = $i{$_}->{area};
         my $t = $i{$_}->{type};
         my $content;

         if ($a eq 'kernel') {
            if ($t eq 'C::Function' || $t eq 'C::Global' || $t eq 'C::Declaration') {
               $content = $out{extern_h};
            } elsif ($t eq 'C::Macro') {
               $content = $out{kernel_macro};
            } else {
               $content = $out{kernel_h};
            }
         } else {
            if ($t eq 'C::Function' || $t eq 'C::Global' || $t eq 'C::Declaration' || $t eq 'C::Acslcomment') {
               $content = $out{module_c};
            } elsif ($t eq 'C::Macro') {
               $content = $out{module_macro};
            } else {
               $content = $out{module_h};
            }
         }

         push @$content, $o;
      }

      $graph->delete_vertices(@zv);
   }

   unshift @{$out{kernel_h}}, @{$out{kernel_macro}};
   unshift @{$out{module_h}}, @{$out{module_macro}};
   delete @out{qw/kernel_macro module_macro/};

   {
      my $c  = $graph->get_graph_attribute('comments');
      my $ms = $graph->get_graph_attribute('module_strings');
      my $ks = $graph->get_graph_attribute('kernel_strings');

      my %ids = map {$_ => undef} @$ids;
      foreach (keys %out) {
         foreach (@{$out{$_}}) {
            #my $id = $_->id;
            if ($_->area eq 'kernel') {
               $_ = $_->to_string($c, $remove_fields, $fullkernel);
            } else {
               unless (exists $ids{$_->id}) {
                  $_ = $_->to_string($c, 0, $full);
               } else {
                  $_ = $_->to_string($c, 0, 1);
               }
            }
            #$_ = "// " . (join(" ", sort @{$debug{$id} || []})) . "\n" . $_ if $_;
         }
      }

      %out = map {
         $_ => join("\n\n", grep {$_} @{$out{$_}})
      } keys %out;

      foreach (qw/module_h module_c/) {
         restore($out{$_}, comments => $c, strings => $ms);
      }

      foreach (qw/kernel_h extern_h/) {
         restore($out{$_}, strings => $ks);
      }
   }

   _write_to_files($output_dir, $output_file, $single_file, \%out, $call);
}

1;

__DATA__
digraph g
{
   subgraph cluster_kernel {
      kernel_macro;
      kernel_structure;
      kernel_declaration;
      kernel_function;
      kernel_typedef;
      kernel_enum;
      kernel_global;

      kernel_macro -> kernel_macro;
      kernel_macro -> kernel_structure;
      kernel_macro -> kernel_declaration;
      kernel_macro -> kernel_function;
      kernel_macro -> kernel_typedef;
      kernel_macro -> kernel_enum;
      kernel_macro -> kernel_global;

      kernel_structure -> kernel_macro;
      kernel_structure -> kernel_structure;
      kernel_structure -> kernel_declaration;
      kernel_structure -> kernel_function;
      kernel_structure -> kernel_typedef;
      kernel_structure -> kernel_enum; //sizeof
      kernel_structure -> kernel_global;

      kernel_declaration -> kernel_macro;
      kernel_declaration -> kernel_global;
      kernel_declaration -> kernel_function;

      kernel_function -> kernel_macro;
      kernel_function -> kernel_global;
      kernel_function -> kernel_function;

      kernel_typedef -> kernel_macro;
      kernel_typedef -> kernel_structure;
      kernel_typedef -> kernel_declaration;
      kernel_typedef -> kernel_function;
      kernel_typedef -> kernel_typedef;
      kernel_typedef -> kernel_enum;
      kernel_typedef -> kernel_global;

      kernel_enum -> kernel_macro;
      kernel_enum -> kernel_structure;
      kernel_enum -> kernel_declaration;
      kernel_enum -> kernel_function;
      kernel_enum -> kernel_typedef;
      kernel_enum -> kernel_enum;
      kernel_enum -> kernel_global;

      kernel_global -> kernel_macro;
      kernel_global -> kernel_global;
      kernel_global -> kernel_function;
   }

   subgraph cluster_module {
      module_macro;
      module_structure;
      module_function;
      module_declaration;
      module_typedef;
      module_enum;
      module_global;
      module_acslcomment;

      // Not sure this is a good idea.
      // In most cases inline plugin should be used instead.
      module_macro -> kernel_macro;

      module_macro -> module_macro;
      module_macro -> module_structure;
      module_macro -> module_function;
      module_macro -> module_declaration;
      module_macro -> module_typedef;
      module_macro -> module_enum;
      module_macro -> module_global;
      module_macro -> module_acslcomment;
      //
      kernel_macro -> module_macro;
      kernel_macro -> module_structure;
      kernel_macro -> module_function;
      kernel_macro -> module_declaration;
      kernel_macro -> module_typedef;
      kernel_macro -> module_enum;
      kernel_macro -> module_global;
      kernel_macro -> module_acslcomment;

      module_structure -> module_macro;
      module_structure -> module_structure;
      module_structure -> module_function;
      module_structure -> module_declaration;
      module_structure -> module_typedef;
      module_structure -> module_enum; //sizeof
      module_structure -> module_global;
      module_structure -> module_acslcomment;
      //
      kernel_structure -> module_macro;
      kernel_structure -> module_structure;
      kernel_structure -> module_function;
      kernel_structure -> module_declaration;
      kernel_structure -> module_typedef;
      kernel_structure -> module_enum; //sizeof
      kernel_structure -> module_global;
      kernel_structure -> module_acslcomment;

      module_function -> module_macro;
      module_function -> module_global;
      module_function -> module_function;
      //
      kernel_declaration -> module_macro;
      kernel_declaration -> module_global;
      kernel_declaration -> module_function;
      //
      kernel_function -> module_macro;
      kernel_function -> module_global;
      kernel_function -> module_function;

      module_declaration -> module_macro;
      module_declaration -> module_global;
      module_declaration -> module_function;

      module_declaration -> kernel_macro;
      module_declaration -> kernel_global;
      module_declaration -> kernel_function;

      module_typedef -> module_macro;
      module_typedef -> module_structure;
      module_typedef -> module_function;
      module_typedef -> module_declaration;
      module_typedef -> module_typedef;
      module_typedef -> module_enum;
      module_typedef -> module_global;
      module_typedef -> module_acslcomment;
      //
      kernel_typedef -> module_macro;
      kernel_typedef -> module_structure;
      kernel_typedef -> module_function;
      kernel_typedef -> module_declaration;
      kernel_typedef -> module_typedef;
      kernel_typedef -> module_enum;
      kernel_typedef -> module_global;
      kernel_typedef -> module_acslcomment;

      module_enum -> module_macro;
      module_enum -> module_structure;
      module_enum -> module_function;
      module_enum -> module_declaration;
      module_enum -> module_typedef;
      module_enum -> module_enum;
      module_enum -> module_global;
      module_enum -> module_acslcomment;
      //
      kernel_enum -> module_macro;
      kernel_enum -> module_structure;
      kernel_enum -> module_function;
      kernel_enum -> module_declaration;
      kernel_enum -> module_typedef;
      kernel_enum -> module_enum;
      kernel_enum -> module_global;
      kernel_enum -> module_acslcomment;

      module_global -> module_macro;
      module_global -> module_function;
      module_global -> module_acslcomment;
      module_global -> module_global;
      //
      kernel_global -> module_macro;
      kernel_global -> module_function;
      kernel_global -> module_acslcomment;
      kernel_global -> module_global;

      module_acslcomment -> module_acslcomment;
      module_acslcomment -> module_macro;
   }
}
