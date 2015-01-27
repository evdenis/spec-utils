use warnings;
use strict;

use Plack::Request;
use Plack::Builder;
use YAML::XS qw/LoadFile/;

use File::Spec::Functions qw/catdir/;
use lib::abs catdir('..', 'lib');

use Plack::Util;
use Plack::MIME;
use HTTP::Date;
use File::Slurp qw/read_file write_file/;
use Try::Tiny;

use Local::App::Graph;

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

read_config '.config';
$config{conf} = LoadFile($config{graph_config_file});
delete $config{graph_config_file};

$config{functions} = [];
$config{async}     = 0;
$config{view}      = 0;
$config{keep_dot}  = 0;

$config{out}        .= $$;
$config{cache_file} .= $$;


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

sub generate_image
{
   try {
      run(\%config)
   } catch {
      return -1
   };

   if ($config{format} eq 'svg') {
      my $filename = $config{out} . '.' . $config{format};
      my $svg = read_file($filename);

      while ($svg =~ /<g id="node/g) {
         my $begin = $-[0];
         my $pos = pos($svg);

         my $end = index($svg, "</g>\n", $begin) + 5;
         my $area = substr($svg, $begin, $end - $begin);
         my ($title) = $area =~ m!<title>([a-zA-Z_]\w++)</title>!;
         next unless $title;
         my $link_begin = qq|<a xlink:href="/graph/image?func=${title}">\n|;
         my $link_end   = qq|</a>\n|;

         substr($svg, $end, 0, $link_end);
         substr($svg, $begin, 0, $link_begin);
         pos($svg) = $pos + length($link_begin) + length($link_end);
      }

      write_file($filename, $svg);
   }

   return 0
}

my $image = sub {
   my $env = shift;


   my $req = Plack::Request->new($env);
   my $res = $req->new_response(200);

   if ($req->param('fmt')) {
      if ($config{format} =~ m/(png)|(svg)|(jpg)|(jpeg)|(tiff)/) {
         $config{format} = $req->param('fmt')
      } else {
         return return_403
      }
   }
   if ($req->param('func')) {
      $config{functions} = [ split(/,/, $req->param('func')) ]
   }

   return return_403
      if generate_image();

   my $file = $config{out} . '.' . $config{format};
   $config{format} = 'svg';
   $config{functions} = [];

   open my $fh, "<:raw", $file
      or return return_403;

   my @stat = stat $file;
   Plack::Util::set_io_path($fh, Cwd::realpath($file));

   return [
      200,
      [
         'Content-Type' => Plack::MIME->mime_type($file),
         'Content-Length' => $stat[7],
         'Last-Modified' => HTTP::Date::time2str( $stat[9] )
      ],
      $fh,
   ];
 
};

my $page = sub {
   #return return_404;
   my $env = shift;
   my $html = <<'HTML';
<!DOCTYPE html>
<html>
   <head>
      <meta charset="UTF-8">
      <script src="http://code.jquery.com/jquery-latest.min.js"></script>
      <title>Functions graph</title>
      <script>
         $(document).ready(function() {
            $("image").mouseenter(function() {
               $(this).stop().animate({transform, scale(2)}, 3000);
            }
         }
      </script>
   </head>

   <body>
      <object data="/graph/image" type="image/svg+xml" id="map"></object>
   </body>

</html>
HTML

   my $req = Plack::Request->new($env);
   my $res = $req->new_response(200);

   $res->body($html);

   return $res->finalize();
};

my $main_app = builder {
   mount '/graph/image' => builder { $image };
   mount '/graph' => builder { $page };
   mount '/map'   => builder { $page };
   mount '/favicon.ico' => builder { \&return_404 };
   mount '/'      => builder { \&return_404 };
};

