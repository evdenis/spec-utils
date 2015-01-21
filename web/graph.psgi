use warnings;
use strict;

use Plack::Request;
use Plack::Builder;

use File::Spec::Functions qw/catdir/;
use lib::abs catdir('..', 'lib');

#use Local::App::Graph;
#use Plack::App::File;
use Plack::Util;
use Plack::MIME;
use HTTP::Date;

my %config;
sub read_config
{
   open my $fh, '<', $_[0] or die "Can't read config file.\n";
   while (<$fh>) {
      s/#.*+\Z//;
      next if /\A\h*+\Z/;
      if (/\A\h*+(\w++)\h*+=\h*+(\w++)\h*+\Z/) {
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

sub return_403
{
   my $self = shift;
   return [403, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['forbidden']];
}

sub generate_image
{
}

my $image = sub {
   my $env = shift;

   my $req = Plack::Request->new($env);
   my $res = $req->new_response(200);

   open my $fh, "<:raw", 'graph.svg'
      or return return_403;

   my @stat = stat 'graph.svg';
   Plack::Util::set_io_path($fh, Cwd::realpath('graph.svg'));

   return [
      200,
      [
         'Content-Type' => 'image/svg+xml',
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
   mount '/graph/graph.svg' => builder { $image };
   mount '/graph/map.svg'   => builder { $image };
   mount '/graph' => builder { $page };
   mount '/map'   => builder { $page };
   mount '/'      => builder { $page };
};

