#!/usr/bin/perl

use File::Spec;
use RSS::Tree;
use TestAgent;
use Test::More;
use XML::Feed;
use strict;


my $BASE_URL = 'http://rss.tree.test/test/';

my $agent = TestAgent->new(File::Spec->catfile(Cwd::getcwd, 'feeds'), $BASE_URL);

{

package RenderTest;

our @ISA = qw(RSS::Tree);

sub render {
    my ($self, $item) = @_;
    return '--' . $item->description . '--';
}

}

my $tree = RenderTest->new(
    agent => $agent,
    feed => "${BASE_URL}render-test-feed.xml",
    name => 'ROOT',
);

my $feed = XML::Feed->parse(\$tree->run);
my @items = $feed->items;

is(@items, 1);
is($items[0]->content->body, '--foo--');

