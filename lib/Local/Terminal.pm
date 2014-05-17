package Local::Terminal;

use warnings;
use strict;

use Exporter qw(import);

our @EXPORT_OK = qw(window_size);


sub window_size
{
   require 'sys/ioctl.ph';

   unless (defined &TIOCGWINSZ) {
      warn "no TIOCGWINSZ\n";
      goto ERR
   }

   unless (open(TTY, "+</dev/tty")) {
      warn "No tty: $!";
      goto ERR
   }

   my $winsize;
   unless (ioctl(TTY, &TIOCGWINSZ, $winsize='')) {
      warn sprintf("$0: ioctl TIOCGWINSZ (%08x: $!)\n", &TIOCGWINSZ);
      goto ERR
   }

   return (unpack('S4', $winsize))[0,1];

ERR:
   return ();
}


1;
