package Local::App::Graph;
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

use Local::List::Utils qw(uniq difference any);
use Local::C::Transformation;
use Local::Kernel::Module qw(preprocess_module_sources_nocomments);
use Local::Kernel::Module::Graph qw(build_sources_graph get_successors_subgraph);

use C::FunctionSet;
use Carp;


BEGIN {
   eval {
      require Smart::Comments;
      Smart::Comments->import();
   }
}

use Exporter qw(import);

our @EXPORT = qw/run/;


sub run
{
   my $opts = ( ref $_[0] eq 'HASH' ) ? shift : { @_ };

   my $tmpl = {
      kernel_dir   => { required => 1, defined => 1 },
      module_dir   => { required => 1, defined => 1 },
      cache        => { required => 0, defined => 1 },
      cache_file   => { required => 1, defined => 1 },
      conf         => { required => 1, defined => 1 },
      done         => { required => 0 },
      preprocessed => { required => 0 },
      functions    => { required => 0 },
      mark_anyway  => { default => 1 },
      stat         => { default => 0 },
      keep_dot     => { default => 0 },
      issues       => { default => 0 },
      async        => { default => 0 },
      view         => { default => 0 },
      priority     => { default => 1 },
      out          => { default => 'graph' },
      format       => { default => 'svg' },
      open_with    => { default => 'xdg-open' },
   };

   check($tmpl, $opts, 1)
      or croak "Arguments could not be parsed.\n";

   #Initializing the library
   Local::Kernel::Module::Graph::init(human_readable => 1, reverse => 1);

   if ($opts->{cache}) {
      unless (-r $opts->{cache_file}) {
         $opts->{cache} = 0
      }
   }
   goto CACHE if $opts->{cache};

   # read sources
   my $source;
   if ($opts->{preprocessed}) {
      $source = read_file($opts->{preprocessed}, scalar_ref => 1);
   } else {
      $source = (preprocess_module_sources_nocomments($opts->{kernel_dir}, $opts->{module_dir}, ["#define SPECIFICATION 1\n"]))[1];
   }
   adapt($$source, attributes => 1, comments => 1);

   #funcs init
   my %sources;
   $sources{module}{function} = C::FunctionSet->parse($source, 'module');
   my $graph = build_sources_graph(\%sources);

   #these are special kernel functions generated after preprocessing
   $graph->delete_vertices( qw(__check_enabled __inittest) );

CACHE: if ($opts->{cache}) {
      $graph = retrieve($opts->{cache_file})
   } else {
      store($graph, $opts->{cache_file})
   }


   #1
   $graph->set_vertex_attribute($_, shape => 'octagon')
      foreach $graph->successorless_vertices();

   my $stat_done = 0;
   my @marked_as_done;

   if ($opts->{done}) {
      ### MARKING VERIFIED FUNCTIONS
      #sub label_done { "\N{BALLOT BOX WITH CHECK} " . join( '', map { $_ . "\N{U+0336}" } split '', $_[0] ) }
      #sub label_done { join( '', map { $_ . "\N{U+0336}" } split '', $_[0] ) }
      sub label_done { state $mark = "\N{BALLOT BOX WITH CHECK} "; $mark . $_[0] }

      foreach (uniq @{ $opts->{conf}{done} }) {
         if ($graph->has_vertex($_)) {
            $graph->set_vertex_attribute($_, 'label', label_done($_));
            $graph->set_vertex_attribute($_, style   => 'dashed');
            $graph->set_vertex_attribute($_, done    => 1);
            $stat_done++;
            push @marked_as_done, $_;
         } else {
            warn "Done: there is no function: '$_'\n"
         }
      }

      #check @marked_as_done
      foreach($graph->all_successors(@marked_as_done)) {
         warn "Predecessor of '$_' is marked as done, but this function isn't.\n"
            unless any($_, @marked_as_done);
      }
   }


   my @stat_priority;
   if ($opts->{priority}) {
      ### MARKING PRIORITIES
      while ( my ($i, $list) = each $opts->{conf}{priority}{lists} ) {
         my $color = $opts->{conf}{priority}{colors}{$list};
         my %stat = ( done => 0, remains => 0);

         foreach (uniq @$list) {
            if ($graph->has_vertex($_)) {

               unless ($graph->has_vertex_attribute($_, 'priority')) {
                  unless ($graph->has_vertex_attribute($_, 'done')) {
                     $graph->set_vertex_attribute($_, style => 'filled' );
                     $graph->set_vertex_attribute($_, fillcolor => $color );
                     $graph->set_vertex_attribute($_, shape => 'tripleoctagon' );
                     $stat{remains}++
                  } else {
                     $stat{done}++
                  }
                  $graph->set_vertex_attribute($_, priority => $i + 1);
               } else {
                  if ($opts->{mark_anyway}) {
                     $graph->set_vertex_attribute($_, fillcolor => $color );
                     $graph->set_vertex_attribute($_, shape => 'tripleoctagon' );
                  }
                  my $lev = $graph->has_vertex_attribute($_, 'priority');
                  warn "'$_' has been already marked as $lev priority level function\n";
                  next
               }

               foreach ($graph->all_successors($_)) {
                  unless ($graph->has_vertex_attribute($_, 'priority')) {
                     unless ($graph->has_vertex_attribute($_, 'done')) {
                        $graph->set_vertex_attribute($_, style => 'filled' );
                        $graph->set_vertex_attribute($_, fillcolor => $color );
                        $stat{remains}++
                     } else {
                        $stat{done}++
                     }
                     $graph->set_vertex_attribute($_, priority => $i + 1);
                  }
               }
            } else {
               warn "Priority list: there is no such function '$_' in sources.\n"
            }
         }

         push @stat_priority, \%stat;
      }
   }

#4
   my %used_issues;
   if ($opts->{issues}) {
      ### MARKING ISSUES
      my $mark = "\N{SALTIRE}";
      foreach (keys %{ $opts->{conf}{issues} }) {
         foreach my $v ($graph->vertices) {
            if ($graph->get_vertex_attribute($v, 'object')->code =~ m/$opts->{conf}{issues}{$_}{re}/) {
               $used_issues{$_} = undef;

               unless ($graph->has_vertex_attribute($v, 'done')) {
                  unless (($graph->get_vertex_attribute($v, 'shape') // '') eq 'record') {
                     $graph->set_vertex_attribute($v, shape => 'record');
                     $graph->set_vertex_attribute($v, style =>
                        ($graph->get_vertex_attribute($v, 'style') // '')  . ',bold');
                     $graph->set_vertex_attribute($v, label => "$mark $v | $_");
                  } else {
                     $graph->set_vertex_attribute($v, label =>
                        $graph->get_vertex_attribute($v, 'label') . " | $_")
                  }
               } else {
                  warn "Issue $_ in already done function '$v'\n"
               }
            }
         }
      }

      my @diff = difference([ keys %{ $opts->{conf}{issues} } ], [ keys %used_issues ]);
      if (@diff) {
         warn "Issues @diff is/are useless, since there is no vertices marked.\n"
      }
   }

   if ($opts->{stat}) {
      ### GATHERING STATISTICS
      say "\n--- Статистика ---";
      say "Общее количество функций: " . $graph->vertices;
      if ($opts->{priority}) {
         say "Функции по уровням приоритета:";
         print map
            {
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
      say "Всего сделано: " . $stat_done if $opts->{done};
   }

   if (@{ $opts->{functions} }) {
      ### GRAPH REDUCING
      my @e;
      foreach (@{ $opts->{functions} }) {
         unless ($graph->has_vertex($_)) {
            warn "There is no such function: '$_'.\n"
         } else {
            push @e, $_
         }
      }

      if (@e) {
         $graph = get_successors_subgraph($graph, @e);

         say "Количество функций в подграфе в выбранном подграфе: " . $graph->vertices
            if $opts->{stat};
      } else {
         warn "--functions parameter will not be taken into account.\n"
      }
   }

   my $dotfile = $opts->{out} . '.dot';

   {
      local $SIG{__WARN__} = sub {};
      Graph::Writer::Dot->new()->write_graph($graph, $dotfile)
   }

   if ($opts->{priority} || $opts->{issues}) {
      my @legenda;

      if ($opts->{issues} && %used_issues) {
         push @legenda, qq(  subgraph "cluster_issues_legenda" {\n);
         push @legenda, qq(    style = "filled";\n);
         push @legenda, qq(    color = "lightgrey";\n);
         push @legenda, qq(    label = "Issues legenda";\n);
         push @legenda, qq(    node [shape = "box", style = "filled"];\n);
         if (keys %used_issues > 1) {
            my $edges = join(' -> ', map { "\"$_\"" } keys %used_issues);
            push @legenda, qq(    $edges [style = "invis"];\n);
         }
         foreach (keys %used_issues) {
            push @legenda, qq(    "$_" [label = "$_: $opts->{conf}{issues}{$_}{description}", fillcolor = "white"];\n);
         }
         push @legenda, qq(  }\n);
      }

      if ($opts->{priority}) {
         push @legenda, qq(  subgraph "cluster_priority_legenda" {\n);
         push @legenda, qq(    style = "filled";\n);
         push @legenda, qq(    color = "lightgrey";\n);
         push @legenda, qq(    label = "Priority levels";\n);
         push @legenda, qq(    node [shape = "box", style = "filled"];\n);
         push @legenda, qq(    "1" -> "2" -> "3" -> "4" -> "5" [ style = "invis" ];\n);
         my $colors = [ map { $opts->{conf}{priority}{colors}{$_} } @{ $opts->{conf}{priority}{lists} } ];
         while (my ($idx, $color) = each $colors) {
            ++$idx;
            push @legenda, qq(    "$idx" [fillcolor = "$color"];\n);
         }
         push @legenda, qq(  }\n);
      }

      my @dot = read_file($dotfile, { binmode => ':utf8' });
      splice @dot, 2, 0, @legenda;
      write_file($dotfile, { binmode => ':utf8' }, @dot);
   }

   if (which('dot')) {
      if ($opts->{async}) {
         fork and return;
      }
      my $output = $opts->{out} . '.' . $opts->{format};
      system('dot', "-T" . $opts->{format}, "$dotfile", "-o${output}");
      unlink $dotfile
         unless $opts->{keep_dot};

      if ($opts->{view}) {
         if (which($opts->{open_with})) {
            close STDOUT;
            close STDERR;
            exec($opts->{open_with}, $output)
         } else {
            croak("Can't find $opts->{open_with} program to view the $output\n")
         }
      }
      if ($opts->{async}) {
         exit 0;
      }
   } else {
      croak("Can't find dot program to create the source map.\n");
   }

}
