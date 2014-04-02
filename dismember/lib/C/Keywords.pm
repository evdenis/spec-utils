package C::Keywords;

use Exporter qw(import);

use Local::C::Parsing;

our @EXPORT = qw(@keywords);
our @EXPORT_OK = qw(@keywords_to_filter);

our @keywords = @Local::C::Parsing::keywords;
our @keywords_to_filter = grep { $_ ne 'struct' && $_ ne 'union' && $_ ne 'enum' } @keywords;

1;
