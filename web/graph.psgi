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
         unless (exists $config{$key}) {
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


sub return_403
{
   my $self = shift;
   return [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']];
}

sub generate_image
{
   run(\%config);
}

my $image = sub {
   my $env = shift;

   generate_image();

   my $req = Plack::Request->new($env);
   my $res = $req->new_response(200);

   if ($req->param('fmt')) {
      if ($config{format} =~ m/(png)|(svg)|(jpg)|(jpeg)|(tiff)/;) {
         $config{format} = $req->param('fmt')
      } else {
         return return_403
      }
   }
   my $file = $config{out} . '.' . $config{format};
   $config{format} = 'svg';

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
   my $env = shift;

   my $req = Plack::Request->new($env);
   my $res = $req->new_response(200);

   my $params = $req->parameters();

   $res->body('ok');

   return $res->finalize();
};

my $main_app = builder {
   mount '/graph/image' => builder { $image };
   mount '/graph' => builder { $image };
   mount '/map'   => builder { $image };
   mount '/'      => builder { $image };
};

