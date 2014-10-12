package Local::String::Utils;

use Exporter qw(import);

use strict;
use warnings;

use re '/aa';

our @EXPORT_OK = qw(normalize ltrim rtrim trim);


sub normalize ($)
{
   my $s = shift;

   $s =~ s/\s++/ /g;
   $s =~ s/\A\s++|\s++\Z//g;

   $s
}


sub ltrim ($) { my $s = shift; $s =~ s/^\s++//; $s }
sub rtrim ($) { my $s = shift; $s =~ s/\s+$//; $s }
sub trim  ($) { my $s = shift; $s =~ s/^\s++|\s+$//g; $s }

1;
