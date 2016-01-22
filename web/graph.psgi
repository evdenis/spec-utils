use warnings;
use strict;

use Plack::Request;
use Plack::Builder;
use YAML::XS qw/LoadFile/;

use File::Spec::Functions qw/catdir catfile/;
use FindBin;
use lib::abs catdir('..', 'lib');

use Plack::Util;
use Plack::MIME;
use HTTP::Date;
use File::Slurp qw/read_file write_file/;
use Try::Tiny;
use File::Modified;

use App::Graph;

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

read_config catfile $FindBin::Bin, '.config';
$config{config} = LoadFile($config{graph_config_file});
my $cmonitor = File::Modified->new(files => [$config{graph_config_file}]);
delete $config{graph_config_file};

$config{functions} = [];
$config{async}     = 0;
$config{keep_dot}  = 0;

$config{out}        .= $$;
$config{cache_file} .= $$;
my $cache_default = $config{cache};


sub return_403
{
   my $self = shift;
   return [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']];
}

sub return_404
{
   my $self = shift;
   return [404, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['not found']];
}

sub return_500
{
   my $self = shift;
   return [500, ['Content-Type' => 'text/plain', 'Content-Length' => 37], ["Internal error. Can't generate image."]];
}

sub generate_image
{
   if (my (@cf) = $cmonitor->changed) {
      try {
         $config{config} = LoadFile($cf[0]);
         warn "Loading updated configuration\n";
      } catch {
         warn "Can't load updated configuration\n"
      };
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
      my $link_begin_end = qq|">\n|;
      if ($_[0] eq 'image') {
         $link_begin = qq|<a xlink:href="/graph/image?func=|;
      } elsif ($_[0] eq 'page') {
         $link_begin = qq|<a xlink:href="/graph?func=|;
      }
      my $link_end   = qq|</a>\n|;

      while ($svg =~ /<g id="node/g) {
         my $begin = $-[0];
         my $pos = pos($svg);

         my $end = index($svg, "</g>\n", $begin) + 5;
         my $area = substr($svg, $begin, $end - $begin);
         my ($title) = $area =~ m!<title>([a-zA-Z_]\w++)</title>!;
         next unless $title;
         my $link = $link_begin . $title . $link_begin_end;

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

   return return_500
      if generate_image('image');

   my $file = $config{out} . '.' . $config{format};
   $config{format} = $original{format};
   $config{functions} = $original{functions};

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
      </style>
      <title>Functions graph</title>
   </head>

   <body>
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

   $config{format} = $original{format};
   $config{functions} = $original{functions};

   return $res->finalize();
};

my $main_app = builder {
   mount '/graph/image' => builder { $image };
   mount '/graph'       => builder { $page };
   mount '/map'         => builder { $page };
   mount '/favicon.ico' => builder { \&return_404 };
   mount '/'            => builder { \&return_404 };
};
