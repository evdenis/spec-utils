package C::Keywords;

use warnings;
use strict;

use Exporter qw(import);

use RE::Common qw($varname);
use Local::C::Parsing;

our @EXPORT = qw(@keywords);
our @EXPORT_OK = qw(prepare_tags);

our @keywords = @Local::C::Parsing::keywords;

my @special_labels = qw(struct union enum . ->);

sub not_special_label
{
   my $t = shift;

   ! scalar grep {$t eq $_} @special_labels
}


our @keywords_to_filter = grep { not_special_label($_) } @keywords;
my %keywords_filter = map { $_ => undef } @keywords_to_filter;


sub prepare_tags
{
   my $code = $_[0];
   my %filter = map { $_ => undef } @{$_[1]};
   my $name = qr/\b($varname)\b/;

   #remove strings
   $code =~ s/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'//g;

   my @tokens;
   while ($code =~ m/(|$name|(\.|->))/g) {
      if (not_special_label($1)) {
         push @tokens, $1
      } else {
         my $special = $1;

         #pop @token; remove previous; + a.b; + a->b; - .b = ;
         $special = 'field'
            if $special eq '.' || $special eq '->';

         push @tokens, [$special, $1]
            if $code =~ m/\G\s*+$name/gc
      }
   }

   my @tags;
   my %uniq;
   foreach (@tokens) {
      my $id;
      if (ref $_ eq 'ARRAY') {
         $id = $_->[0] . ' ' . $_->[1]
      } else {
         next if exists $keywords_filter{$_};
         $id = $_
      }

      push @tags, $_
         if !$uniq{$id}++ && !exists $filter{$id}
   }

   \@tags
}

1;
