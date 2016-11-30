package C::Util::Transformation;

use re '/aa';

use warnings;
use strict;

use Exporter qw(import);
use Carp;
use Local::List::Util qw(uniq);


our @EXPORT = qw(adapt);
our @EXPORT_OK = qw(
         restore
         restore_comments
         restore_attributes
         restore_strings
         restore_macro
         filter
         filter_dup
         filter_comments
         filter_comments_dup
         norm

         %comment_t
         %attribute_t
         %string_t
         %macro_t

         $s $h
);
our %EXPORT_TAGS = (TYPES => [qw(%comment_t %attribute_t %string_t %macro_t)], RE => [qw($s $h)]);

#TODO: md5 hash

our %comment_t   = ( L => '$', R => '$' );
our %attribute_t = ( L => '$', R => '`' );
our %string_t    = ( L => '$', R => '#' );
our %macro_t     = ( L => '$', R => '@' );

{
   foreach my $i (\%comment_t, \%attribute_t, \%string_t, \%macro_t) {
      $i->{pattern} = qr/\Q$i->{L}\E(\d++)\Q$i->{R}\E/
   }
}

our ($s, $h, $replacement, $special_symbols) = (undef, undef, undef, '');

{
   my @left;
   my @right;

   foreach (\%comment_t, \%attribute_t, \%string_t, \%macro_t) {
      push @left,  $_->{L};
      push @right, $_->{R};
   }

   @left  = uniq(@left);
   @right = uniq(@right);
   $special_symbols = join('', uniq(@left, @right));

   $replacement = '[' . join('', @left) . ']' . '\d++' . '[' . join('', @right) . ']';
   $replacement = qr/$replacement/;
   $s = qr/(?:\s++|${replacement})/;
   $h = qr/(?:[ \t]++|${replacement})/;
}


sub generic_remove
{
   #my $code    = shift; #$_[0]
   my $pattern = $_[1];
   my $t       = $_[2];
   my $opts    = ( ref $_[3] eq 'HASH' ) ? $_[3] : { @_[3..$#_] };

   my $save    = $opts->{save};
   my $sub     = $opts->{sub};

   my $res = undef;

   if ($save) {
      if ($sub) {
         $_[0] =~ s/$pattern/$sub->($save, \%+)/ge
      } else {
         $_[0] =~ s/$pattern/push @$save, ${^MATCH}; "$t->{L}$#$save$t->{R}"/gpe
      }
      #push @$save, $t->{pattern} Storable can't save REGEXP's
   } else {
      if ($sub) {
         $_[0] =~ s/$pattern/$sub->(\%+)/ge
      } else {
         $_[0] =~ s/$pattern//g
      }
   }

   $res
}

sub remove_comments
{
   my $sub = undef;
   my $pattern = qr!/\*[^*]*\*+(?:[^/*][^*]*\*+)*/|//(?:[^\\]|[^\n][\n]?)*?(?=\n)|(?<other>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|.[^/"'\\]*)!sp;

   if (defined $_[1]) {
      $sub  = sub { if (defined $_[1]->{other}) { ${^MATCH} } else { push @{$_[0]}, ${^MATCH}; "$comment_t{L}$#{$_[0]}$comment_t{R}" } }
   } else {
      $sub  = sub { if (defined $_[0]->{other}) { ${^MATCH} } else {''} }
   }

   generic_remove(
      $_[0],
      $pattern,
      \%comment_t,
      save => $_[1],
      sub  => $sub 
   )
}

sub remove_strings
{
   my $sub = undef;
   my $pattern = qr!(?<other>/\*[^*]*\*+(?:[^/*][^*]*\*+)*/|//(?:[^\\]|[^\n][\n]?)*?(?=\n))|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|(?<other>.[^/"'\\]*)!sp;

   if (defined $_[1]) {
      $sub  = sub { if (defined $_[1]->{other}) { ${^MATCH} } else { push @{$_[0]}, ${^MATCH}; "$string_t{L}$#{$_[0]}$string_t{R}" } }
   } else {
      $sub  = sub { if (defined $_[0]->{other}) { ${^MATCH} } else {''} }
   }

   generic_remove(
      $_[0],
      $pattern,
      \%string_t,
      save => $_[1],
      sub  => $sub 
   )
}

sub remove_attributes
{
   generic_remove(
      $_[0],
      qr/__attribute(?:__)?\s*(?>(?<attr>\((?:(?>[^\(\)]+)|(?&attr))*\)))/,
      \%attribute_t,
      save => $_[1]
   )
}

sub remove_macro
{
   generic_remove(
      $_[0],
      qr/
         ^
         [ \t]*
         \#
         [ \t]*
         (?:
              (?:
                  e(?:lse|ndif)
                  |
                  line
                  |
                  include
                  |
                  undef
               )
               .*
            |
               (?:
               define
               |
               elif
               |
               ifn?(?:def)?
               )
               [ \t]+
               (?<mbody>
                  .*(?=\\\n)
                  \\\n
                  (?&mbody)?
               )?
               .+
         )
         $
      /mx,
      \%macro_t,
      save => $_[1]
   )
}

sub adapt
{
   my $opts = ( ref $_[1] eq 'HASH' ) ? $_[1] : { @_[1..$#_] };

   return undef
      unless $_[0];

   croak("Wrong arguments\n") if grep {!/attributes|macro|strings|comments/} keys %$opts;

   my $tmpl = sub {
      if ($_[0]) {
         if (ref $_[0] eq 'ARRAY') {
            $_[1]->($_[2], $_[0])
         } else {
            $_[1]->($_[2])
         }
      }
   };

   $tmpl->($opts->{comments},   \&remove_comments,   $_[0]);
   $tmpl->($opts->{strings},    \&remove_strings,    $_[0]);
   $tmpl->($opts->{macro},      \&remove_macro,      $_[0]);
   $tmpl->($opts->{attributes}, \&remove_attributes, $_[0]);

   undef
}


#TODO: return value? delete elements of array?
sub generic_restore
{
   $_[0] =~ s!$_[2]!$_[1]->[$1]!g;
}

sub restore_comments
{
   generic_restore(@_, $comment_t{pattern});
}

sub restore_strings
{
   generic_restore(@_, $string_t{pattern});
}

sub restore_attributes
{
   generic_restore(@_, $attribute_t{pattern});
}

sub restore_macro
{
   generic_restore(@_, $macro_t{pattern});
}

sub restore
{
   my $opts = ( ref $_[1] eq 'HASH' ) ? $_[1] : { @_[1..$#_] };

   return undef
      unless $_[0];

   croak("Wrong arguments\n") if grep {!/attributes|macro|strings|comments/} keys %$opts;

   #The order matters.
   restore_attributes($_[0], $opts->{attributes}) if $opts->{attributes};
   restore_macro     ($_[0], $opts->{macro})      if $opts->{macro};
   restore_strings   ($_[0], $opts->{strings})    if $opts->{strings};
   restore_comments  ($_[0], $opts->{comments})   if $opts->{comments};

   undef
}

sub filter_comments ($)
{
   $_[0] =~ s/$comment_t{pattern}//g;

   undef
}

sub filter_comments_dup ($)
{
   $_[0] =~ s/$comment_t{pattern}//gr
}


sub filter ($)
{
   $_[0] =~ s/$replacement//g;

   undef
}

sub filter_dup ($)
{
   $_[0] =~ s/$replacement//gr
}

sub norm ($)
{
   $_[0] =~ s/${s}++//rg
}

1;
