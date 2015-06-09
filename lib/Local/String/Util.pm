package Local::String::Util;

use Exporter qw(import);

use strict;
use warnings;

use re '/aa';

our @EXPORT_OK = qw(normalize ltrim rtrim trim remove_spaces eq_spaces ne_spaces is_blank);


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

sub remove_spaces ($)
{
   $_[0] =~ s/\s++//gr
}

sub eq_spaces ($$)
{
   remove_spaces($_[0]) eq remove_spaces($_[1])
}

sub ne_spaces ($$)
{
   !eq_spaces($_[0], $_[1])
}

sub is_blank ($)
{
   $_[0] =~ m/\A\s++\Z/
}

1;
