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
#  Limit tests:
#

my $tree = RSS::Tree->new(
    agent => $agent,
    feed  => "${BASE_URL}simple.xml",
    name => 'ROOT',
    limit => 2,
);

my ($feed, @items);

$feed = XML::Feed->parse(\$tree->run);

is($feed->items, 2);

{

package LimitTestTree;

use constant LIMIT => 1;

our @ISA = qw(RSS::Tree);

}

$tree = LimitTestTree->new(
    agent => $agent,
    feed  => "${BASE_URL}simple.xml",
    name => 'ROOT',
);

$feed = XML::Feed->parse(\$tree->run);

is($feed->items, 1);

#
# Autoclean tests:
#

$tree = RSS::Tree->new(
    agent => $agent,
    feed  => "${BASE_URL}autoclean-test.xml",
    name => 'ROOT',
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;

is(@items, 1);

my $xtree = HTML::TreeBuilder::XPath->new;
$xtree->parse($items[0]->content->body);
$xtree->eof;

my @divs = $xtree->findnodes('//div');
is(@divs, 4);
is((grep { grep !/^_/, $_->all_attr_names } @divs), 0);
is(() = $xtree->findnodes('//script'), 0);

$tree = RSS::Tree->new(
    agent => $agent,
    feed  => "${BASE_URL}autoclean-test.xml",
    name => 'ROOT',
    autoclean => 0,
);

{

package AutocleanTestTree;

use constant AUTOCLEAN => 0;

our @ISA = qw(RSS::Tree);

}

my $tree2 = AutocleanTestTree->new(
    agent => $agent,
    feed  => "${BASE_URL}autoclean-test.xml",
    name => 'ROOT',
);

for my $t ($tree, $tree2) {
    $feed = XML::Feed->parse(\$t->run);
    @items = $feed->items;

    is(@items, 1);

    $xtree = HTML::TreeBuilder::XPath->new;
    $xtree->parse($items[0]->content->body);
    $xtree->eof;

    is(() = $xtree->findnodes('//script'), 2);
    is(() = $xtree->findnodes('//div[@id]'), 1);
    is(() = $xtree->findnodes('//div[attribute::*[starts-with(name(),"data-")]]'), 2);
    is(() = $xtree->findnodes('//div[attribute::*[starts-with(name(),"item")]]'), 2);
    is(() = $xtree->findnodes('//div[@onclick]'), 1);
}

#
# Autoresolve tests:
#

$tree = RSS::Tree->new(
    agent => $agent,
    feed  => "${BASE_URL}autoresolve-test.xml",
    name => 'ROOT',
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;

is(@items, 1);

$xtree = HTML::TreeBuilder::XPath->new;
$xtree->parse($items[0]->content->body);
$xtree->eof;

my ($elem) = $xtree->findnodes('//a');
is($elem->attr('href'), 'https://github.com/grimnebulin/href.html');

($elem) = $xtree->findnodes('//img');
is($elem->attr('src'), 'https://github.com/grimnebulin/foo.jpg');

($elem) = $xtree->findnodes('//iframe');
is($elem->attr('src'), 'https://github.com/grimnebulin/bar');

($elem) = $xtree->findnodes('//embed');
is($elem->attr('src'), 'https://github.com/grimnebulin/baz');

($elem) = $xtree->findnodes('//input');
is($elem->attr('src'), 'submit.png');

($elem) = $xtree->findnodes('//area');
is($elem->attr('href'), 'rectangle.html');

{

package AutoresolveTestAgent;

our @ISA = qw(TestAgent);

sub head {
    my ($self, $url) = @_;
    return HTTP::Response->new(200, undef, [ 'Content-Base' => 'https://github.com/grimnebulin/redirected/' ])
}

}

$tree = RSS::Tree->new(
    agent => AutoresolveTestAgent->new(File::Spec->catfile(Cwd::getcwd, 'feeds'), $BASE_URL),
    feed  => "${BASE_URL}autoresolve-test.xml",
    name => 'ROOT',
    autoresolve => 'follow',
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;

is(@items, 1);

$xtree = HTML::TreeBuilder::XPath->new;
$xtree->parse($items[0]->content->body);
$xtree->eof;

($elem) = $xtree->findnodes('//a');
is($elem->attr('href'), 'https://github.com/grimnebulin/redirected/href.html');

($elem) = $xtree->findnodes('//img');
is($elem->attr('src'), 'https://github.com/grimnebulin/redirected/foo.jpg');

($elem) = $xtree->findnodes('//iframe');
is($elem->attr('src'), 'https://github.com/grimnebulin/redirected/bar');

($elem) = $xtree->findnodes('//embed');
is($elem->attr('src'), 'https://github.com/grimnebulin/redirected/baz');

($elem) = $xtree->findnodes('//input');
is($elem->attr('src'), 'submit.png');

($elem) = $xtree->findnodes('//area');
is($elem->attr('href'), 'rectangle.html');


$tree = RSS::Tree->new(
    agent => $agent,
    feed  => "${BASE_URL}autoresolve-test.xml",
    name => 'ROOT',
    autoresolve => 0,
);

{

package AutoresolveTestTree;

use constant AUTORESOLVE => 0;

our @ISA = qw(RSS::Tree);

}

$tree2 = AutoresolveTestTree->new(
    agent => $agent,
    feed  => "${BASE_URL}autoresolve-test.xml",
    name => 'ROOT',
);

for my $t ($tree, $tree2) {
    $feed = XML::Feed->parse(\$t->run);
    @items = $feed->items;

    is(@items, 1);

    $xtree = HTML::TreeBuilder::XPath->new;
    $xtree->parse($items[0]->content->body);
    $xtree->eof;

    ($elem) = $xtree->findnodes('//a');
    is($elem->attr('href'), 'href.html');

    ($elem) = $xtree->findnodes('//img');
    is($elem->attr('src'), 'foo.jpg');

    ($elem) = $xtree->findnodes('//iframe');
    is($elem->attr('src'), 'bar');

    ($elem) = $xtree->findnodes('//embed');
    is($elem->attr('src'), 'baz');

    ($elem) = $xtree->findnodes('//input');
    is($elem->attr('src'), 'submit.png');

    ($elem) = $xtree->findnodes('//area');
    is($elem->attr('href'), 'rectangle.html');

}

#
# Wrap content tests
#

$tree = RSS::Tree->new(
    agent => $agent,
    feed => "${BASE_URL}wrap-content-test.xml",
    name => 'ROOT',
    wrap_content => 1,
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;

is(@items, 1);

$xtree = HTML::TreeBuilder::XPath->new(store_comments => 1);
$xtree->parse($items[0]->content->body);
$xtree->eof;

my @guts = $xtree->guts;
is(1, @guts);
is('div', $guts[0]->tag);
my @child = $guts[0]->content_list;
is(3, @child);
is($child[0]->tag, '~comment');
like($child[1], qr/this is text/i);
is($child[2]->tag, '~comment');

{

package WrapContentTestTree;

use constant WRAP_CONTENT => 1;

our @ISA = qw(RSS::Tree);

}

$tree = WrapContentTestTree->new(
    agent => $agent,
    feed => "${BASE_URL}wrap-content-test.xml",
    name => 'ROOT',
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;

is(@items, 1);

$xtree = HTML::TreeBuilder::XPath->new(store_comments => 1);
$xtree->parse($items[0]->content->body);
$xtree->eof;

@guts = $xtree->guts;
is(1, @guts);
is('div', $guts[0]->tag);
@child = $guts[0]->content_list;
is(3, @child);
is($child[0]->tag, '~comment');
like($child[1], qr/this is text/i);
is($child[2]->tag, '~comment');

#
#  Agent configuration tests.
#

$tree = RSS::Tree->new(agent_id => 'Tschai');

is('Tschai', $tree->agent->agent);

{

package AgentIdTestTree;

use constant AGENT_ID => 'Alphanor';

our @ISA = qw(RSS::Tree);

}

$tree = AgentIdTestTree->new;

is('Alphanor', $tree->agent->agent);

$tree = RSS::Tree->new(
    agent_config => {
        max_size => 999,
        max_redirect => 2,
    },
);

is(999, $tree->agent->max_size);
is(2, $tree->agent->max_redirect);

{

package AgentConfigTestTree;

use constant AGENT_CONFIG => {
    parse_head => 0,
    timeout => 1,
};

our @ISA = qw(RSS::Tree);

}

$tree = AgentConfigTestTree->new;

ok(!$tree->agent->parse_head);
is(1, $tree->agent->timeout);

my $lwpagent = LWP::UserAgent->new;

$tree = RSS::Tree->new(
    agent => $lwpagent,
    agent_id => 'foo',
    agent_config => { timeout => $lwpagent->timeout + 1 },
);

ok($tree->agent->agent ne 'foo');
ok($tree->agent->timeout == $lwpagent->timeout);
