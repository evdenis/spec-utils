package App::Graph;
use warnings;
use strict;

use feature qw(say state);

use utf8::all;

use Graph;
use Graph::Writer::Dot;

use File::Slurp qw(read_file write_file);
use File::Which;
use Params::Check qw(check);
use Storable;

use Local::List::Util qw(uniq difference intersection any);
use C::Util::Transformation;
use Kernel::Module qw(preprocess_module_sources_nocomments);
use Kernel::Module::Graph qw(
  build_sources_graph
  get_successors_subgraph
  get_strict_successors_subgraph
  get_predecessors_subgraph
  get_strict_predecessors_subgraph
);
use Configuration qw(switch_system);

use C::FunctionSet;
use Carp;

BEGIN {
   eval {
      require Smart::Comments;
      Smart::Comments->import();
   }
}

use Exporter qw(import);

our @EXPORT = qw(run);

sub run
{
   my $args = (ref $_[0] eq 'HASH') ? shift : {@_};

   my $tmpl = {
      kernel_dir      => {required => 1, defined => 1},
      module_dir      => {required => 1, defined => 1},
      mname           => {required => 0, default => undef},
      type            => {required => 0, default => undef},
      cache           => {required => 0, defined => 1},
      cache_file      => {required => 1, defined => 1},
      config          => {default  => undef},
      renew_cache     => {required => 0},
      done            => {required => 0},
      from_done       => {required => 0, default => 0},
      display_done    => {default  => 1},
      preprocessed    => {required => 0},
      functions       => {required => 0},
      mark_anyway     => {default  => 1},
      statistics      => {default  => 0},
      keep_dot        => {default  => 0},
      issues          => {default  => 0},
      async           => {default  => 0},
      view            => {default  => undef},
      priority        => {default  => 1},
      reverse         => {default  => 0},
      priority_legend => {default  => 1},
      issues_legend   => {default  => 1},
      level           => {default  => undef},
      out             => {default  => 'graph'},
      format          => {default  => 'svg'},
   };

   $args = check($tmpl, $args, 1)
     or croak "Arguments could not be parsed.\n";

   if ($args->{type}) {
      croak "Unknown system type " . $args->{type} . "\n"
        unless switch_system($args->{type});
   }

   if (defined $args->{level}) {
      croak "Can't handle arguments --functions and --level simultaneously.\n"
        if @{$args->{functions}};
      my $level = $args->{level};
      my $max   = @{$args->{config}{priority}{lists}};
      if ($level <= 0 || $level > $max) {
         warn "Level option is out of bounds. Ignoring.\n";
         $args->{level} = undef;
      } else {
         $args->{functions} = $args->{config}{priority}{lists}[$args->{level} - 1];
      }
   }

   if ($args->{config}{done} && $args->{from_done}) {
      if (!$args->{reverse} && $args->{display_done} == 0) {
         croak "It's pointless to use --from-done and --no-display-done.\n";
      }
      my @from_done = @{$args->{config}{done}};    #clone
      push @from_done, @{$args->{config}{'specs-only'}}
        if exists $args->{config}{'specs-only'};
      push @from_done, @{$args->{config}{'lemma-proof-required'}}
        if exists $args->{config}{'lemma-proof-required'};
      push @from_done, @{$args->{config}{'partial-specs'}}
        if exists $args->{config}{'partial-specs'};

      if (@{$args->{functions}}) {
         $args->{functions} = [intersection($args->{functions}, \@from_done)];
         carp "Intersection of --level and --from-done options results in empty set.\n"
           unless @{$args->{functions}};
      } else {
         $args->{functions} = \@from_done;
      }
   }

   #Initializing the library
   Kernel::Module::Graph::init(human_readable => 1, reverse => 1);

   if ($args->{renew_cache}) {
      $args->{cache} = 0;
   }

   if ($args->{cache}) {
      unless (-r $args->{cache_file}) {
         $args->{cache} = 0;
      }
   }
   goto CACHE if $args->{cache};

   # read sources
   my $source;
   if ($args->{preprocessed}) {
      $source = read_file($args->{preprocessed}, scalar_ref => 1);
   } else {
      $source = (
         preprocess_module_sources_nocomments(
            $args->{kernel_dir}, $args->{module_dir}, $args->{mname}, ["#define SPECIFICATION 1\n"]
         )
      )[1];
   }
   adapt($$source, attributes => 1, comments => 1);

   #funcs init
   my %sources;
   $sources{module}{function} = C::FunctionSet->parse($source, 'module');
   my $graph = build_sources_graph(\%sources);

   #these are special kernel functions generated after preprocessing
   $graph->delete_vertices(qw(__check_enabled __inittest __exittest));

 CACHE: if ($args->{cache}) {
      $graph = retrieve($args->{cache_file});
   } else {
      store($graph, $args->{cache_file});

      exit 0
        if $args->{renew_cache};
   }

   my $stat_done = 0;
   my @marked_as_done;

   if ($args->{done}) {
      ### MARKING VERIFIED FUNCTIONS
      sub label_done {state $mark = "\N{BALLOT BOX WITH CHECK} "; $mark . $_[0]}
      my %how_to_mark = (
         done => {
            label         => \&label_done,
            shape         => 'hexagon',
            style         => 'bold',
            count_as_done => 1
         },
         'specs-only' => {
            label         => \&label_done,
            shape         => 'hexagon',
            style         => 'dotted',
            count_as_done => 1
         },
         'partial-specs' => {
            shape => 'hexagon',
            style => 'dotted'
         },
         'lemma-proof-required' => {
            label         => \&label_done,
            shape         => 'hexagon',
            style         => 'dashed',
            count_as_done => 1
         }
      );
      my @done_categories = keys %how_to_mark;

      foreach my $mark (@done_categories) {
         foreach my $func (uniq @{$args->{config}{$mark}}) {
            if ($graph->has_vertex($func)) {
               $graph->set_vertex_attribute($func, label => $how_to_mark{$mark}{label}->($func))
                 if exists $how_to_mark{$mark}{label};
               foreach my $attr (qw(style shape)) {
                  $graph->set_vertex_attribute($func, $attr => $how_to_mark{$mark}{$attr})
                    if exists $how_to_mark{$mark}{$attr};
               }
               $graph->set_vertex_attribute($func, done => 1);
               $stat_done++
                 if $how_to_mark{$mark}{count_as_done};
               push @marked_as_done, $func;
            } else {
               warn ucfirst($mark) . ": there is no function: '$func'\n";
            }
         }
      }

      #check @marked_as_done
      foreach ($graph->all_successors(@marked_as_done)) {
         warn "Predecessor of '$_' is marked as done, but this function isn't.\n"
           unless any($_, @marked_as_done);
      }
   }

   my @stat_priority;
   if ($args->{priority}) {
      ### MARKING PRIORITIES
      while (my ($i, $list) = each @{$args->{config}{priority}{lists}}) {
         my $color = $args->{config}{priority}{colors}{$list};
         my %stat = (done => 0, remains => 0);

         foreach (uniq @$list) {
            if ($graph->has_vertex($_)) {

               unless ($graph->has_vertex_attribute($_, 'priority')) {
                  unless ($graph->has_vertex_attribute($_, 'done')) {
                     $graph->set_vertex_attribute($_, style     => 'filled');
                     $graph->set_vertex_attribute($_, fillcolor => $color);
                     $graph->set_vertex_attribute($_, shape     => 'tripleoctagon');
                     $stat{remains}++;
                  } else {
                     $stat{done}++;
                  }
                  $graph->set_vertex_attribute($_, priority => $i + 1);
               } else {
                  if ($args->{mark_anyway}) {
                     $graph->set_vertex_attribute($_, fillcolor => $color);
                     $graph->set_vertex_attribute($_, shape     => 'tripleoctagon');
                  }
                  my $lev = $graph->has_vertex_attribute($_, 'priority');
                  warn "'$_' has been already marked as $lev priority level function\n";
                  next;
               }

               foreach ($graph->all_successors($_)) {
                  unless ($graph->has_vertex_attribute($_, 'priority')) {
                     unless ($graph->has_vertex_attribute($_, 'done')) {
                        $graph->set_vertex_attribute($_, style     => 'filled');
                        $graph->set_vertex_attribute($_, fillcolor => $color);
                        $stat{remains}++;
                     } else {
                        $stat{done}++;
                     }
                     $graph->set_vertex_attribute($_, priority => $i + 1);
                  }
               }
            } else {
               warn "Priority list: there is no such function '$_' in sources.\n";
            }
         }

         push @stat_priority, \%stat;
      }
   }

   #4
   my %used_issues;
   if ($args->{issues}) {
      ### MARKING ISSUES
      my $mark = "\N{SALTIRE}";
      foreach (keys %{$args->{config}{issues}}) {
         foreach my $v ($graph->vertices) {
            if ($graph->get_vertex_attribute($v, 'object')->code =~ m/$args->{config}{issues}{$_}{re}/) {
               $used_issues{$_} = undef;

               unless ($graph->has_vertex_attribute($v, 'done')) {
                  unless (($graph->get_vertex_attribute($v, 'shape') // '') eq 'record') {
                     $graph->set_vertex_attribute($v, shape => 'record');
                     $graph->set_vertex_attribute($v,
                        style => ($graph->get_vertex_attribute($v, 'style') // '') . ',bold');
                     $graph->set_vertex_attribute($v, label => "$mark $v | $_");
                  } else {
                     $graph->set_vertex_attribute($v, label => $graph->get_vertex_attribute($v, 'label') . " | $_");
                  }
               } else {
                  warn "Issue $_ in already done function '$v'\n";
               }
            }
         }
      }

      my @diff = difference([keys %{$args->{config}{issues}}], [keys %used_issues]);
      if (@diff) {
         warn "Issues @diff is/are useless, since there is no vertices marked.\n";
      }
   }

   if ($args->{statistics}) {
      ### GATHERING STATISTICS
      say "\n--- Статистика ---";
      say "Общее количество функций: " . $graph->vertices;
      if ($args->{priority}) {
         say "Функции по уровням приоритета:";
         print map {
            state $i = 0;
            ++$i;
            my $t = $_->{done} + $_->{remains};
            "\t[$i] общее количество: $t \tсделано: $_->{done} \tосталось: $_->{remains}\n"
         } @stat_priority;

         my ($done, $remains) = (0, 0);
         foreach ($graph->vertices) {
            unless ($graph->has_vertex_attribute($_, 'priority')) {
               if ($graph->has_vertex_attribute($_, 'done')) {
                  $done++;
               } else {
                  $remains++;
               }
            }
         }
         my $total = $done + $remains;
         say "Не вошедших в очереди приоритетов: $total; из них сделано $done; осталось $remains";
      }
      say "Всего сделано: " . $stat_done if $args->{done};
   }

   if (@{$args->{functions}}) {
      ### GRAPH REDUCING
      my @e;
      foreach (@{$args->{functions}}) {
         unless ($graph->has_vertex($_)) {
            warn "There is no such function: '$_'.\n";
         } else {
            push @e, $_;
         }
      }

      if (@e) {
         unless ($args->{reverse}) {
            $graph = get_successors_subgraph($graph, @e);
         } else {
            $graph = get_strict_predecessors_subgraph($graph, @e);
         }

         say "Количество функций в выбранном подграфе: " . $graph->vertices
           if $args->{statistics};
      } else {
         warn "--functions parameter will not be taken into account.\n";
      }
   }

   $graph->delete_vertices(@marked_as_done)
     unless $args->{display_done};

   $graph->set_vertex_attribute($_, shape => 'octagon') foreach $graph->successorless_vertices();

   my $dotfile = $args->{out} . '.dot';

   {
      local $SIG{__WARN__} = sub { };
      Graph::Writer::Dot->new()->write_graph($graph, $dotfile);
   }

   if ($args->{priority} && $args->{priority_legend} || $args->{issues} && $args->{issues_legend}) {
      my @legend;

      if ($args->{issues} && $args->{issues_legend} && %used_issues) {
         push @legend, qq(  subgraph "cluster_issues_legend" {\n);
         push @legend, qq(    style = "filled";\n);
         push @legend, qq(    color = "lightgrey";\n);
         push @legend, qq(    label = "Issues legend";\n);
         push @legend, qq(    node [shape = "box", style = "filled"];\n);
         if (keys %used_issues > 1) {
            my $edges = join(' -> ', map {"\"$_\""} keys %used_issues);
            push @legend, qq(    $edges [style = "invis"];\n);
         }
         foreach (keys %used_issues) {
            push @legend, qq(    "$_" [label = "$_: $args->{config}{issues}{$_}{description}", fillcolor = "white"];\n);
         }
         push @legend, qq(  }\n);
      }

      if ($args->{priority} && $args->{priority_legend}) {
         push @legend, qq(  subgraph "cluster_priority_legend" {\n);
         push @legend, qq(    style = "filled";\n);
         push @legend, qq(    color = "lightgrey";\n);
         push @legend, qq(    label = "Priority levels";\n);
         push @legend, qq(    node [shape = "box", style = "filled"];\n);
         push @legend,
             '    '
           . join(' -> ', map {"\"$_\""} (1 .. @{$args->{config}{priority}{lists}}))
           . ' [ style = "invis" ];' . "\n";
         my @colors = map {$args->{config}{priority}{colors}{$_}} @{$args->{config}{priority}{lists}};
         while (my ($idx, $color) = each @colors) {
            ++$idx;
            push @legend, qq(    "$idx" [fillcolor = "$color"];\n);
         }
         push @legend, qq(  }\n);
      }

      if (@legend) {
         my @dot = read_file($dotfile, {binmode => ':utf8'});
         splice @dot, 2, 0, @legend;
         write_file($dotfile, {binmode => ':utf8'}, @dot);
      }
   }

   if (which('dot')) {
      if ($args->{async}) {
         fork and return;
      }
      my $output = $args->{out} . '.' . $args->{format};
      system('dot', "-T" . $args->{format}, "$dotfile", "-o${output}");
      unlink $dotfile
        unless $args->{keep_dot};

      if (defined $args->{view}) {
         if (which($args->{view})) {
            close STDOUT;
            close STDERR;
            exec($args->{view}, $output);
         } else {
            croak("Can't find $args->{view} program to view the $output\n");
         }
      }
      if ($args->{async}) {
         exit 0;
      }
   } else {
      croak("Can't find dot program to create the source map.\n");
   }
}

1;
