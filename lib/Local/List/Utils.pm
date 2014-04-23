package Local::List::Utils;

use Exporter qw(import);

use strict;
use warnings;


our @EXPORT_OK = qw(any uniq intersection union difference_symmetric difference);

#FIXME: later 2 arrays (@l, @r) doesn't work
#sub uniq (\[$@])
sub uniq
{
   my %uniq;
   if ($#_ == 0) {
      $_[0] = [ grep { !$uniq{$_}++ } @{$_[0]} ]
   } else {
      grep { !$uniq{$_}++ } @_
   }
}

sub any_ref
{
	foreach (@{$_[1]}) {
		return 1 if $_ eq $_[0]
	}
   0
}

sub any_l
{
   my $str = shift;

	foreach (@_) {
		return 1 if $_ eq $str
	}
   0
}

#FIXME: same problem
#sub any ($\[$@])
sub any
{
   return any_l(@_) if $#_ > 2;

   if (ref($_[0]) eq 'ARRAY' ) {
      return any_ref($_[1], $_[0])
   } elsif (ref($_[1]) eq 'ARRAY' ) {
      return any_ref($_[0], $_[1])
   } else {
      return $_[0] eq $_[1] 
   }
}

sub intersection ($$)
{
   my %f = map { $_ => undef } @{$_[0]};

   grep { exists $f{$_} } @{$_[1]}
}

sub union ($$)
{
   my %u;

   $u{$_} = undef foreach (@{$_[0]}, @{$_[1]});

   keys %u
}

sub difference_symmetric ($$)
{
   my %f = map { $_ => undef } @{$_[0]};
   my %s = map { $_ => undef } @{$_[1]};
   my @res;

   foreach (@{$_[0]}, @{$_[1]}) {
      push @res, $_ if (!exists $f{$_}) || (!exists $s{$_});
   }

   @res
}

sub difference ($$)
{
   my %s = map { $_ => undef } @{$_[1]};
   my @res;

   foreach (@{$_[0]}) {
      push @res, $_ if (!exists $s{$_});
   }

   @res
}


1;
