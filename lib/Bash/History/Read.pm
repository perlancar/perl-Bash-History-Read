package Bash::History::Read;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter 'import';
our @EXPORT = qw(each_hist);
our @EXPORT_OK = qw(parse_bash_history_file);

sub _doit {
    my ($which, $code, $fh0) = @_;

    my $call_code = sub {
        my ($ts, $content) = @_;
        package main {
            local $_ = $content;
            local $main::TS = $ts;
            local $main::PRINT = 1;
            $code->();
            if ($main::PRINT) {
                print "#$ts\n" if defined $ts;
                print;
            }
        }
    };

    my $fh;
    if ($which eq 'each_hist') {
        $fh = \*ARGV;
    } else {
        $fh = $fh0;
    }

    my $ts;
    while (defined(my $line = <$fh>)) {
        if ($line =~ /\A#(\d+)$/) {
            $ts = $1;
        } else {
            $call_code->($ts, $line);
            undef $ts;
        }
    }
}

sub each_hist(&) {
    my $code = shift;
    _doit('each_hist', $code);
}

sub parse_bash_history_file {
    my ($path) = @_;

    $path //= $ENV{HISTFILE} // "$ENV{HOME}/.bash_history";

    open my($fh), "<", $path or die "Can't open bash history file '$path': $!";
    my $res = [];
    _doit('parse_bash_history_file',
          sub {
              push @$res, [$main::TS, $_];
              $main::PRINT = 0;
          },
          $fh,
      );
    $res;
}

1;
# ABSTRACT: Utility to read bash history file entries

=head1 SYNOPSIS

From script:

 use Bash::History::Read qw(parse_bash_history_file);

 my $res = parse_bash_history_file("$ENV{HOME}/.bash_history");

Sample result:

 [
   [undef, "some-command\n"],
   [1446715184, "du -sm\n"],
   [1446715190, "ls -l\n"],
 ]

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

=head2 parse_bash_history_file([ $path ]) => array

Parse entries from bash history file. If unspecified, C<$path> will default to
C<HISTFILE> environment variable or C<$HOME/.bash_history>.

Return an array of entries, where each entry is C<<[$timestamp, $line]>> and
C<$timestamp> can be undef if entry does not have a timestamp.

=head2 each_hist { PERL_CODE }

Will read lines from the diamond operator (C<< <> >>) and call Perl code for
each history entry. Can handle timestamp lines. This routine is exported by
default and is meant to be used from one-liners.

Inside the Perl code, C<$_> is locally set to the entry content, C<$TS> is
locally set to the timestamp (and cannot be changed), C<$PRINT> is locally set
to 1. If C<$PRINT> is still true by the time the Perl code ends, the entry
(along with its timestamp) will be printed. So to remove a line, you can set
C<$PRINT> to 0 in your code. To modify content, modify the C<$_> variable.
