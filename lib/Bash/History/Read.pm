package Bash::History::Read;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(each_hist);

sub each_hist(&) {
    my $code = shift;

    my $call_code = sub {
        my ($ts, $content) = @_;
        package main {
            local $_ = $content;
            local $main::TS = $ts;
            local $main::PRINT = 1;
            $code->();
            if ($main::PRINT) {
                print "#$ts\n$_";
            }
        }
    };

    my $ts;
    my $content = "";
    my $cur_line_is = '';
    while (defined(my $line = <>)) {
        if ($line =~ /\A#(\d+)$/) {
            if (defined($ts) && length($content)) {
                # send previous entry
                $call_code->($ts, $content);
            }
            $ts = $1;
            $content = '';
            $cur_line_is = 'ts';
        } elsif (defined $ts) {
            $content .= $line;
            $cur_line_is = 'entry';
        } else {
            die "Invalid input, timestamp line expected";
        }
    }
    if ($cur_line_is eq 'entry') {
        $call_code->($ts, $content);
    }
}

1;
# ABSTRACT: Utility to read bash history file entries

=head1 SYNOPSIS

From the command-line:

 % perl -MBash::History::Read -i.bak -e'each_hist {
       $PRINT = 0 if $TS < time()-2*30*86400; # delete old entries
       $PRINT = 0 if /foo/; # delete unwanted lines (e.g. matching some regex)
       s/(mysql\s+-p)(\S+)/$1******/; # redact sensitive information
   }' ~/.bash_history


=head1 DESCRIPTION

This module provides utility routines to read entries from bash history file (by
default C<~/.bash_history>). The format of the history file is dead simple: one
line per entry, but when C<HISTTIMEFORMAT> environment is set, bash will print a
timestamp line before each entry, e.g.:

 #1374290613
 ls -al
 #1374290618
 less myfile
 #1374290635
 ...

See C<each_hist> for one routine to let you handle this format conveniently.


=head1 FUNCTIONS

=head2 each_hist { PERL_CODE }

Will read lines from the diamond operator (C<< <> >>) and call Perl code for
each history entry. Can handle timestamp lines. This routine is exported by
default and is meant to be used from one-liners.

Inside the Perl code, C<$_> is locally set to the entry content, C<$TS> is
locally set to the timestamp (and cannot be changed), C<$PRINT> is locally set
to 1. If C<$PRINT> is still true by the time the Perl code ends, the entry
(along with its timestamp) will be printed. So to remove a line, you can set
C<$PRINT> to 0 in your code. To modify content, modify the C<$_> variable.
