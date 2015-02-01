package Git_RSS_Items;

use strict;
use warnings;
use autodie;
use HTML::Escape 'escape_html';
use Exporter 'import';
our @EXPORT = qw(git_items);

my $state = 'start'; # Initial state
my $hash  = '';

sub end_item {
    if ($state eq 'diff') {
        print "  </code>]]>\n";
        print " </description>\n";
        print "</item>\n";
    }
}

my %states = (
    diff => sub {
        if (/^vvv ([A-Fa-f0-9]+) vvv$/) {
            $hash = $1;
            end_item();
            $state = 'item';
        } else {
            chomp;
            $_ = escape_html($_);
            if (/^-/) {
                $_ = qq{<font color="#aa0000">$_</font>};
            } elsif (/^\+/) {
                $_ = qq{<font color="#00aa00">$_</font>};
            } elsif (/^===/) {
                $_ = qq{<font color="#aaaa00">$_</font>};
            } elsif (/^Index/) {
                $_ = qq{<font color="#aaaa00">$_</font>};
            }
            s/\t/    /g;
            s{\r}{<font color="#ffffff">^M</font>}g;
            s/^ /&nbsp;/;
            s/  / &nbsp;/g;
            print "  ", $_, "<br>\n";
        }
    },
    item => sub {
        print;
        if (/^ <description>/) {
            $state = 'desc';
        }
    },
    desc => sub {
        if (/^\^{3} $hash \^{3}$/) {
            $state = 'diff';
            print "  <code>\n";
        } else {
            chomp;
            if ($_) {
                print "  <tt>", escape_html($_), "</tt><br>\n";
            } else {
                print "  <br>\n";
            }
        }
    }
);

# Format string for git log
my $format_str =
    'vvv %H vvv%n<item>%n '
  . '<guid>%H</guid>%n '
  . '<title><![CDATA[%h %s]]></title>%n '
  . '<author>%aE (%aN)</author>%n '
  . '<pubDate>%aD</pubDate>%n '
  . '<description><![CDATA[%n%B%n'
  . '^^^ %H ^^^';

sub git_items {
	my @gitlog = `git log -p --format='$format_str' @_`;
    $states{'start'} = $states{'diff'};

    # Execute the state machine
    foreach (@gitlog) {
        $states{$state}->();
    }
    end_item();
}