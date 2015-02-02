package Git_RSS_Items;

use strict;
use warnings;
use autodie;
use HTML::Escape 'escape_html';
use Exporter 'import';
our @EXPORT = qw(git_items);

my $state = 'start';    # Initial state
my $hash  = '';

sub end_item(\@) {
    my ($buffer) = @_;
    if ($state eq 'diff') {
        push @{$buffer}, "  </code>]]>\n";
        push @{$buffer}, " </description>\n";
        push @{$buffer}, "</item>\n";
    }
}

my %states = (
    diff => sub(\@$) {
        my ($buffer, $content) = @_;
        if ($content =~ /^vvv ([A-Fa-f0-9]+) vvv$/) {
            $hash = $1;
            end_item(@{$buffer});
            $state = 'item';
        } else {
            chomp $content;
            $content = escape_html($content);
            if ($content =~ /^-/) {
                $content = qq{<font color="#aa0000">$content</font>};
            } elsif ($content =~ /^\+/) {
                $content = qq{<font color="#00aa00">$content</font>};
            } elsif ($content =~ /^===/) {
                $content = qq{<font color="#aaaa00">$content</font>};
            } elsif ($content =~ /^Index/) {
                $content = qq{<font color="#aaaa00">$content</font>};
            } elsif ($content =~ /^@@/) {
                $content =~
s|(@@ -?\d+(?:,\d+)? \+\d+(?:,\d+)? @@)|<font color="#0000aa">$1</font>|;
            }
            $content =~ s/\t/    /g;
            $content =~ s{\r}{<font color="#ffffff">^M</font>}g;
            $content =~ s/^ /&nbsp;/;
            $content =~ s/  / &nbsp;/g;
            push @{$buffer}, "  " . $content . "<br>\n";
        }
    },
    item => sub(\@$) {
        my ($buffer, $content) = @_;
        push @{$buffer}, $content;
        if ($content =~ /^ <description>/) {
            $state = 'desc';
        }
    },
    desc => sub(\@$) {
        my ($buffer, $content) = @_;
        if ($content =~ /^\^{3} $hash \^{3}$/) {
            $state = 'diff';
            push @{$buffer}, "  <code>\n";
        } else {
            chomp $content;
            if ($content) {
                push @{$buffer},
                  "  <tt>" . escape_html($content) . "</tt><br>\n";
            } else {
                push @{$buffer}, "  <br>\n";
            }
        }
    }
);
$states{'start'} = $states{'diff'};

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

    my @result;

    # Execute the state machine
    foreach my $line (@gitlog) {
        $states{$state}->(\@result, $line);
    }
    end_item(@result);
    return @result;
}
