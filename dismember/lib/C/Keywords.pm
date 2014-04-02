package C::Keywords;

use warnings;
use strict;

use Exporter qw(import);

use Local::C::Parsing;

our @EXPORT = qw(@keywords);
our @EXPORT_OK = qw(prepare_tags);

our @keywords = @Local::C::Parsing::keywords;

my @special_labels = qw(struct union enum);

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
   my $name = qr/\b([a-zA-Z_]\w*+)\b/;

   #remove strings
   $code =~ s/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'//g;

   my @tokens;
   while ($code =~ m/$name/g) {
      if (not_special_label($1)) {
         push @tokens, $1
      } else {
         my $special = $1;
         if ($code =~ m/\G\s*+$name/gc) {
            push @tokens, [$special, $1]
         }
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

      if (!$uniq{$id}++ && !exists $filter{$id}) {
         push @tags, $_
      }
   }

   @tags = map { ref $_ eq 'ARRAY' ? @{$_} : $_ } @tags; #temp

   \@tags
}

1;
