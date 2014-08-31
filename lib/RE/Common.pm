package RE::Common;

use re '/aa';

use warnings;
use strict;

use Exporter qw/import/;

our @EXPORT_OK = qw/$varname/;


our $varname = qr/[a-zA-Z_]\w*+/;

1;
