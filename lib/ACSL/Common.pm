package ACSL::Common;

use warnings;
use strict;

use re '/aa';

use Exporter qw(import);

our @EXPORT_OK = qw(is_acsl_spec);

sub is_acsl_spec ($)
{
   $_[0] =~ m!^\s*+(?:/\*\@|//\@)!
}

1;
