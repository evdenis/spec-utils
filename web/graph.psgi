use warnings;
use strict;

use Plack::Request;
use Plack::Builder;

use File::Spec::Functions qw/catdir catfile/;
use FindBin;
use lib::abs catdir('..', 'lib');

use Plack::Util;
use Plack::MIME;
use HTTP::Date;
use File::Slurp qw/read_file write_file/;
use Try::Tiny;
use File::Modified;
use Scalar::Util qw(looks_like_number);
use DBI;
use JSON qw/encode_json/;

use App::Graph;
use Local::Config qw(load_config merge_config_keys update_config_keys);
use Local::Config::Format qw(check_priority_format check_status_format detect_and_check_format);

my %config;
sub read_config
{
   open my $fh, '<', $_[0] or die "Can't read config file.\n";
   while (<$fh>) {
      s/#.*+\Z//;
      next if /\A\h*+\Z/;
      if (/\A\h*+(\w++)\h*+=\h*+([\w\/\-\.]++)\h*+\Z/) {
         my ($key, $value) = ($1, $2);
         if (exists $config{$key}) {
            warn "Option $key has been already set.\n"
         }
         $config{$key} = $value
      } else {
         warn "Error in config string '$_'. Can't parse. Skipping.\n"
      }
   }
   close $fh;
}

my $ppid = getppid();
my $config_file = $ENV{GRAPH_CONFIG} // '.config';
read_config catfile $FindBin::Bin, $config_file;
my $priority = load_config $config{priority_config_file};
unless ($priority) {
   warn "Can't read priority config file.\n";
   kill "SIGKILL", $ppid;
}
my $status   = load_config $config{status_config_file};
unless ($status) {
   warn "Can't read status config file.\n";
   kill "SIGKILL", $ppid;
}

if (!check_status_format($status) || !check_priority_format($priority)) {
   warn "Wrong file format.\n";
   kill "SIGKILL", $ppid;
}
merge_config_keys $config{config}, $priority;
merge_config_keys $config{config}, $status;

my $cmonitor = File::Modified->new(files => [@config{qw/priority_config_file status_config_file/}]);
delete $config{priority_config_file};
delete $config{status_config_file};

$config{functions} = [];
$config{async}     = 0;
$config{keep_dot}  = 0;
$config{issues}    = 0;

$config{out}        .= $$;
$config{cache_file} .= $$;
my $cache_default = $config{cache};

my $dbh = undef;
my $sth = undef;
if (exists $config{dbfile} && -r $config{dbfile}) {
   $dbh = DBI->connect("dbi:SQLite:dbname=$config{dbfile}", "", "", {
        PrintError       => 0,
        RaiseError       => 1,
        AutoCommit       => 1,
        FetchHashKeyName => 'NAME_lc',
   });
   $dbh->{sqlite_unicode} = 1;
   $sth = $dbh->prepare('SELECT * FROM astraver_functions WHERE name = ?');
}
delete $config{dbfile};

sub return_403
{
   return [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']];
}

sub return_404
{
   return [404, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['not found']];
}

sub return_500
{
   return [500, ['Content-Type' => 'text/plain', 'Content-Length' => 37], ["Internal error. Can't generate image."]];
}

sub return_503
{
   return [503, ['Content-Type' => 'text/plain', 'Content-Length' => 26], ["Database isn't configured."]];
}


sub generate_image
{
   if (my (@cf) = $cmonitor->changed) {
      try {
             my $new_config;
             foreach (@cf) {
                my $c = load_config $_;
                if (detect_and_check_format($c)) {
                   merge_config_keys $new_config, $c;
                } else {
                   warn "Incorrect configuration update. Will use previous.\n";
                }
             }
             update_config_keys $config{config}, $new_config;
             warn "Loading updated configuration @cf\n";
      } catch {
         warn "Can't load updated configuration\n"
      };
      $cmonitor->update();
   }

   my $fail = 0;
   try {
      $config{cache} = $cache_default;
      run(\%config)
   } catch {
      warn "Can't generate image: $_\n";
      $fail = 1;
   };

   if ($fail) {
      return -1
   }

   if ($config{format} eq 'svg') {
      my $filename = $config{out} . '.' . $config{format};
      my $svg = read_file($filename);

      my $link_begin;
      my $link_level_begin;
      my $link_begin_end = qq|">\n|;
      if ($_[0] eq 'image') {
         $link_begin       = qq|<a xlink:href="/graph/image?func=|;
         $link_level_begin = qq|<a xlink:href="/graph/image?level=|;
      } elsif ($_[0] eq 'page') {
         $link_begin       = qq|<a xlink:href="/graph?func=|;
         $link_level_begin = qq|<a xlink:href="/graph?level=|;
      }
      my $link_end   = qq|</a>\n|;

      while ($svg =~ /<g id="node/g) {
         my $begin = $-[0];
         my $pos = pos($svg);

         my $end = index($svg, "</g>\n", $begin) + 5;
         my $area = substr($svg, $begin, $end - $begin);
         my ($title) = $area =~ m!<title>([a-zA-Z_]\w++|\d++)</title>!;
         next unless $title;
         my $link;
         unless (looks_like_number($title)) {
            $link = $link_begin.$title.$link_begin_end;
         } else {
            $link = $link_level_begin.$title.$link_begin_end;
         }

         substr($svg, $end, 0, $link_end);
         substr($svg, $begin, 0, $link);
         pos($svg) = $pos + length($link) + length($link_end);
      }

      write_file($filename, $svg);
   }

   return 0
}

my $image = sub {
   my $env = shift;
   my %original = (format => $config{format}, functions => $config{functions});

   my $req = Plack::Request->new($env);

   if ($req->param('fmt')) {
      if ($config{format} =~ m/(png)|(svg)|(jpg)|(jpeg)/) {
         $config{format} = $req->param('fmt')
      } else {
         return return_403
      }
   }
   if ($req->param('func')) {
      $config{functions} = [ split(/,/, $req->param('func')) ]
   }
   if ($req->param('level') && looks_like_number($req->param('level'))) {
      $config{level} = $req->param('level')
   }
   if ($req->param('no-display-done')) {
      $config{display_done} = 0
   }
   if ($req->param('reverse')) {
      $config{reverse} = 1
   }
   if ($req->param('from-done')) {
      $config{from_done} = 1
   }
   if ($req->param('available')) {
      $config{from_done}    = 1;
      $config{reverse}      = 1;
      $config{display_done} = 0;
   }
   if (defined $req->param('legenda') && !$req->param('legenda')) {
      $config{priority_legenda} = 0;
      $config{issues_legenda} = 0;
   }

   return return_500
      if generate_image('image');

   my $file = $config{out} . '.' . $config{format};
   $config{format}       = $original{format};
   $config{functions}    = $original{functions};
   delete $config{level};
   delete $config{display_done};
   delete $config{reverse};
   delete $config{from_done};
   delete $config{priority_legenda};
   delete $config{issues_legenda};

   open my $fh, "<:raw", $file
      or return return_500;

   my @stat = stat $file;
   my $mime = Plack::MIME->mime_type($file);
   Plack::Util::set_io_path($fh, Cwd::realpath($file));

   return [
      200,
      [
         'Content-Type'   => $mime,
         'Content-Length' => $stat[7],
         'Last-Modified'  => HTTP::Date::time2str( $stat[9] )
      ],
      $fh,
   ];

};

my $page = sub {
   my $env = shift;
   my %original = (format => $config{format}, functions => $config{functions});
   my $html_svg = <<'HTML';
<!DOCTYPE html>
<html>
   <head>
      <meta charset="UTF-8">

      <style type="text/css">
         body {
            overflow: hidden;
         }
         table {
            border-collapse: collapse;
            width: 100%;
         }
         td, th {
            padding: 3px;
            border: 1px solid black;
            text-align: center;
         }
         th {
            background: #b0e0e6;
         }
      </style>

      <script
         src="https://code.jquery.com/jquery-3.1.1.min.js"
         integrity="sha256-hVVnYaiADRTO2PzUGmuLJr8BLUSjGIZsDYGmIJLv2b8="
         crossorigin="anonymous">
      </script>

      <link rel="stylesheet" href="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/styles/default.min.css">
      <script src="//cdnjs.cloudflare.com/ajax/libs/highlight.js/9.8.0/highlight.min.js"></script>

      <script>
         var kordered = [
         "priority",
         "status",
         "ccn",
         "sloc",
         "level",
         "module_calls",
         "kernel_calls",
         "args"
         ];

         var hdr = {
         "module_calls": "MC",
         "sloc" : "SLOC",
         "args" : "ARGS",
         "level": "LVL",
         "kernel_calls": "KC",
         "priority": "PRIO",
         "ccn": "CCN",
         "status": "STATUS",
         "name": "NAME",
         "code": "CODE"
         };

         $(function() {
            $("g.node").contextmenu(function(event) {
               fname = $(this).children("title").text();
               $.ajax("/info?func=" + fname).done(function(result) {
                  //$("#finfo__name").text(result.name);
                  var columns = "<tr>";
                  var values  = "<tr>";
                  kordered.forEach(function (k) {
                     v = result[k];
                     if (v === "") { v = "UNDEF"; }
                     if (v === null) { v = -1; }
                     columns += "<th><b>" + hdr[k] + "</b></th>";
                     values  += "<td>" + v.toString() + "</td>";
                  });
                  columns += "</tr>";
                  values  += "</tr>";

                  var tbody = $("#tbody");
                  tbody.html(columns);
                  tbody.append(values);

                  $("#finfo__code").text(result.code);

                  hljs.highlightBlock($("#finfo__code")[0]);

                  $("#finfo").css({
                     top: event.pageY + 5,
                     left: event.pageX + 5
                  }).show();
               });

               return false;
            });

            $("body").click(function() {
               $("#finfo").hide();
            });

            $("body").contextmenu(function(evt) {
                $("#finfo").hide(); return false;
            });
         });
      </script>

      <style>
         #finfo {
            position: absolute;
            top: 20px;
            left: 20px;
            background-color: white;
            border: solid 1px black;
            display: none;
         }

         #finfo__code {
            font-family: monospace;
            white-space: pre;
         }
      </style>

      <title>Functions graph</title>
   </head>

   <body data-gr-c-s-loaded="true">
      <div id="finfo">
         <div id="finfo__name"><table><tbody id="tbody"></tbody></table></div>
         <div id="finfo__code"></div>
      </div>
      ###INLINE###
   </body>
   <script>
var sx = 0, sy = 0;
function move(e) {
   var e = window.event || e;
   var ww = window.innerWidth;
   var wh = window.innerHeight;
   var y = e.clientY;
   var x = e.clientX;
   var xp = x / ww;
   var yp = y / wh;

   if (xp <= 0.15) {
      sx = -10
   } else if (xp >= 0.85) {
      sx = 10
   } else {
      sx = 0
   }

   if (yp <= 0.15) {
      sy = -10
   } else if (yp >= 0.85) {
      sy = 10
   } else {
      sy = 0
   }

   return false;
}

function stop(e) {
	e = e ? e : window.event;
	var from = e.relatedTarget || e.toElement;
	if (!from || from.nodeName == "HTML") {
		sx = sy = 0;
	}
}

hljs.configure({
   languages: ["c"]
});

var c = 1;
var g = document.getElementById("graph0");

function change(e) {
   var e = window.event || e;

   if (0.1 <= c && c <= 1) {
      if (e != null) {
         var delta = Math.max(-1, Math.min(1, (e.wheelDelta || -e.deltaY || -e.detail)));
         c += delta * 0.1;
      }
      g.transform.baseVal.getItem(0).setScale(c, c);
   } else {
      if (c < 0.1) {
         c = 0.1
      } else if (c > 1) {
         c = 1
      }
      change(null)
   }
   return false;
}

window.DOMMouseScroll = window.onwheel = window.onmousewheel = document.onmousewheel = change;

window.onload = function () {
   document.addEventListener('mousemove', move, false);
   document.addEventListener('mouseout', stop, false);
   setInterval(
      function(){
         if (sx != 0 || sy != 0) {
            window.scrollBy(sx, sy)
         }
      }, 10);
}
   </script>
</html>
HTML
   my $html = <<'HTML';
<!DOCTYPE html>
<html>
   <head>
      <meta charset="UTF-8">
      <title>Functions graph</title>
   </head>

   <body>
   <img src="/graph/image###INLINE###">
   </body>
</html>
HTML


   my $req = Plack::Request->new($env);
   my $res = $req->new_response(200);

   if ($req->param('fmt')) {
      if ($config{format} =~ m/(png)|(svg)|(jpg)|(jpeg)/) {
         $config{format} = $req->param('fmt')
      } else {
         return return_403
      }
   }
   if ($req->param('func')) {
      $config{functions} = [ split(/,/, $req->param('func')) ]
   }
   if ($req->param('level') && looks_like_number($req->param('level'))) {
      $config{level} = $req->param('level')
   }
   if ($req->param('no-display-done')) {
      $config{display_done} = 0
   }
   if ($req->param('reverse')) {
      $config{reverse} = 1
   }
   if ($req->param('from-done')) {
      $config{from_done} = 1
   }
   if ($req->param('available')) {
      $config{from_done}    = 1;
      $config{reverse}      = 1;
      $config{display_done} = 0;
   }
   if (defined $req->param('legenda') && !$req->param('legenda')) {
      $config{priority_legenda} = 0;
      $config{issues_legenda} = 0;
   }

   if ($config{format} eq 'svg') {
      my $filename = $config{out} . '.' . $config{format};

      return return_500
         if generate_image('page');

      my $svg = read_file($filename);
      unlink $filename;
      $html_svg =~ s/###INLINE###/$svg/;
      $html = $html_svg;
   } else {
      my $get = '?';
      if ($req->param('fmt')) {
         $get .= 'fmt=' . $req->param('fmt')
      }
      if ($req->param('func')) {
         $get .= '&func=' . $req->param('func')
      }
      $html =~ s/###INLINE###/$get/
         if $get
   }

   $res->body($html);

   $config{format}       = $original{format};
   $config{functions}    = $original{functions};
   delete $config{level};
   delete $config{display_done};
   delete $config{reverse};
   delete $config{from_done};
   delete $config{priority_legenda};
   delete $config{issues_legenda};

   return $res->finalize();
};

my $info = sub {
   my $env = shift;
   
   return return_503
      if !$dbh || !$sth;

   my $req = Plack::Request->new($env);
   my $func;
   if ($req->param('func')) {
      $func = $req->param('func')
   } else {
      return return_403
   }

   $sth->execute($func);
   my $hash = $sth->fetchrow_hashref; $sth->finish(); #$dbh->disconnect;

   return return_404
      unless $hash;

   my $res = $req->new_response(200);
   $res->content_type('application/json');
   $res->body(encode_json($hash));

   return $res->finalize();
};

my $main_app = builder {
   mount '/graph/image' => builder { $image };
   mount '/graph'       => builder { $page };
   mount '/map'         => builder { $page };
   mount '/info'        => builder { $info };
   mount '/favicon.ico' => builder { \&return_404 };
   mount '/'            => builder { \&return_404 };
};
