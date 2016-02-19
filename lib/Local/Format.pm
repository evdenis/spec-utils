package Local::Format;
use strict;
use warnings;

use Exporter qw(import);
use Carp;
use Color::Library;
use Try::Tiny;

our @EXPORT_OK = qw(check_issues_format check_status_format check_priority_format);

sub check_issues_format($)
{
    my $conf = shift @_;
    my $ok = 1;

    try {
        my $fail = 0;

        unless (exists $conf->{issues}) {
            carp "Issues configuration should have 'issues' key.\n";
            $fail = 1;
            goto FAIL;
        }

        my $i = $conf->{issues};
        foreach (keys %$i) {
            unless (exists $i->{$_}{description}) {
                carp "Issues configuration suppose each issue have 'description' key.\n";
                $fail = 1;
                goto FAIL;
            }
            unless (exists $i->{$_}{re}) {
                carp "Issues configuration suppose each issue have 'decsription' key.\n";
                $fail = 1;
                goto FAIL;
            }
        }
        # Don't check re compiles. Takes too long.

FAIL:
        if ($fail) {
            $ok = 0;
        }
    } catch {
        carp "Issues configuration file has improper structure. $_\n";
        $ok = 0;
    };

    return $ok;
}

sub check_status_format($)
{
    my $conf = shift @_;
    my $ok = 1;

    try {
        my $fail = 0;
        my @keys = keys %$conf;

        # Check categories
        foreach (@keys) {
            unless ($_ eq 'done' || $_ eq 'specs-only' || $_ eq 'partial-specs' || $_ eq 'lemma-proof-required') {
                carp "State configuration format doesn't support $_ key.\n";
                $fail = 1;
                goto FAIL;
            }
        }

        my %f;
        # Check functions uniq
        foreach (@keys) {
            foreach (@{$conf->{$_}}) {
                if (exists $f{$_}) {
                    carp "State configuration format doesn't allow to use function name ($_) more than one time.\n";
                    $fail = 1;
                    goto FAIL;
                } else {
                    $f{$_} = undef;
                }
            }
        }

FAIL:
        if ($fail) {
            $ok = 0;
        }
    } catch {
        carp "State configuration file has improper structure. $_\n";
        $ok = 0;
    };

    return $ok;
}

sub check_priority_format($)
{
    my $conf = shift @_;
    my $ok = 1;

    try {
        my $fail = 0;

        unless (exists $conf->{priority}) {
            carp "Priority configuration should have 'priority' key.\n";
            $fail = 1;
            goto FAIL;
        }
        unless (exists $conf->{priority}{lists}) {
            carp "Priority configuration should have 'lists' key.\n";
            $fail = 1;
            goto FAIL;
        }
        unless (exists $conf->{priority}{colors}) {
            carp "Priority configuration should have 'colors' key.\n";
            $fail = 1;
            goto FAIL;
        }
        my $lists  = $conf->{priority}{lists};
        my $colors = $conf->{priority}{colors};

        unless (@$lists == keys %$colors) {
            carp "Priority configuration should have same number of lists and colors entities.\n";
            $fail = 1;
            goto FAIL;
        }

        #check colors <=> lists binding
        foreach (@$lists) {
            unless (exists $colors->{$_}) {
                carp "Priority configuration format suppose each color refers an appropriate list.\n";
                $fail = 1;
                goto FAIL;
            }
        }

        my %f;
        # Check functions uniq
        foreach (@$lists) {
            foreach (@{$_}) {
                if (exists $f{$_}) {
                    carp "Priority configuration format doesn't allow to use function name ($_) more than one time.\n";
                    $fail = 1;
                    goto FAIL;
                } else {
                    $f{$_} = undef;
                }
            }
        }

        #check colors uniq
        my %c;
        foreach (keys %$colors) {
            my $color = $colors->{$_};
            if (exists $c{$color}) {
                carp "Priority configuration format doesn't allow to use color name ($color) more than one time.\n";
                $fail = 1;
                goto FAIL;
            } else {
                $c{$color} = undef;
            }
        }
        #check colors existance
        foreach my $c (values %$colors) {
            unless (defined Color::Library->color($c)) {
                carp "Priority configuration format doesn't support color $c.\n";
                $fail = 1;
                goto FAIL;
            }
        }

FAIL:
        if ($fail) {
            $ok = 0;
        }
    } catch {
        carp "State configuration file has improper structure. $_\n";
        $ok = 0;
    };

    return $ok;
}

1;