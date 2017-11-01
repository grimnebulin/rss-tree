#!/usr/bin/perl

use File::Spec;
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;
use RSS::Tree;
use TestAgent;
use Test::More;
use XML::Feed;
use strict;


my $BASE_URL = 'http://rss.tree.test/test/';

my $agent = TestAgent->new(File::Spec->catfile(Cwd::getcwd, 'feeds'), $BASE_URL);

#
# clean_feed test
#

{

package CleanFeedTestTree;

our @ISA = qw(RSS::Tree);

sub clean_feed {
    $_[1] =~ s|(\w+)-(\w)ay|$2$1|g;
}

}

my $tree = CleanFeedTestTree->new(
    agent => $agent,
    feed => "${BASE_URL}clean-feed-test.xml",
    name => 'ROOT'
);

my $feed = XML::Feed->parse(\$tree->run);
my @items = $feed->items;

is(@items, 1);

is($items[0]->content->body, 'xyz');

#
# postprocess_item test
#

{

package PostprocessItemTestTree;

our @ISA = qw(RSS::Tree);

sub postprocess_item {
    my ($self, $item) = @_;
    $item->set_title(sprintf '[%s]', $item->title);
    $item->set_author('Jack Vance');
}

}

$tree = PostprocessItemTestTree->new(
    agent => $agent,
    feed => "${BASE_URL}postprocess-item-test.xml",
    name => 'ROOT'
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;

is(@items, 1);
is($items[0]->title, '[Item 1]');
is($items[0]->author, 'Jack Vance');

#
#  decode_response test
#

{

package DecodeResponseTestTree;

our @ISA = qw(RSS::Tree);

sub decode_response {
    my ($self, $response) = @_;
    return $response->decoded_content(raise_error => 1);
}

sub render {
    my ($self, $item) = @_;
    return $item->page;
}

}

{

package DecodeResponseTestAgent;

our @ISA = qw(TestAgent);

sub get {
    my ($self, $url) = @_;
    my $response = shift->SUPER::get($url);
    $response->header('Content-Encoding' => 'utf-1337') if $url =~ /weird/;
    return $response;
}

}

$tree = DecodeResponseTestTree->new(
    agent => DecodeResponseTestAgent->new(File::Spec->catfile(Cwd::getcwd, 'feeds'), $BASE_URL),
    feed => "${BASE_URL}decode-response-test.xml",
    name => 'ROOT',
);

eval { $tree->run };
like($@, qr/don't know how to decode/i);
