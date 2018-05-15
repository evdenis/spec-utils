package RE::Common;

use re '/aa';

use warnings;
use strict;

use Exporter qw(import);

our @EXPORT_OK = qw($varname $acsl_varname $acsl_contract $acsl_invariant $acsl_assert);

our $varname      = qr/[a-zA-Z_]\w*+/;
our $acsl_varname = qr/(:?\\?|\b)[a-zA-Z_]\w*+/;

#
our $acsl_invariant = qr/\b(?:loop|variant|invariant)\b/;
our $acsl_contract  = qr/\b(?:requires|assigns|ensures|allocates|frees)\b/;
our $acsl_assert    = qr/\bassert\b/;

1;
