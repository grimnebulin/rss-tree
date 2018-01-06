#!/usr/bin/perl

use File::Spec;
use HTML::Element;
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;
use RSS::Tree;
use Scalar::Util qw(isweak);
use TestAgent;
use Test::More;
use XML::Feed;
use strict;


my $BASE_URL = 'http://rss.tree.test/test/';

my $agent = TestAgent->new(File::Spec->catfile(Cwd::getcwd, 'feeds'), $BASE_URL);

my $tree = RSS::Tree->new(name => 'ROOT');
my $node = RSS::Tree::Node->new('child', 'kid');
my $node2 = RSS::Tree::Node->new('grandchild', 'grandkid');

$tree->add($node);
$node->add($node2);

is($node->name, 'child');
is($node->title, 'kid');
is($node2->name, 'grandchild');
is($node2->title, 'grandkid');
ok($node->parent == $tree);
ok($node->root == $tree);
ok($tree->root == $tree);
ok($node2->parent == $node);
ok($node2->root == $tree);
ok(!defined $tree->parent);
ok(isweak $node->{parent});
ok(isweak $node2->{parent});

my $feed = XML::Feed->parse(File::Spec->catfile(Cwd::getcwd, 'feeds', 'node-test.xml'));
my ($item) = map { RSS::Tree::Item->new($tree, $_) } $feed->items;

ok($node->test($item));

$node->match_title('Item 1');
ok($node->test($item));
$node->match_title('Item Foo');
ok(!$node->test($item));

$node->match_author('Gersen');
ok($node->test($item));
$node->match_author('Malagate');
ok(!$node->test($item));

$node->match_category('ten');
ok($node->test($item));
$node->match_category('fool');
ok($node->test($item));
$node->match_category('x');
ok(!$node->test($item));

my $div = HTML::Element->new('div', id => 'the-div');
my $body = HTML::Element->new('body')->push_content($div);
my $elem = $node->wrap($div, HTML::Element->new('div', class => 'wrapper'));

is($body->as_HTML, '<body><div class="wrapper"><div id="the-div"></div></div></body>');

$elem = HTML::Element->new(
    'body',
    id => 'n1',
    'data-lore' => 'true',
    itemscope => 'peri',
)->push_content(
    HTML::Element->new(
        'script',
        id => 'n2',
        type => 'text/javascript',
        src => 'none'
    ),
    HTML::Element->new(
        'div',
        id => 'n3',
        itemtype => 'writer',
        onclick => 'alert()'
    )->push_content(
        HTML::Element->new(
            'span',
            id => 'n4',
            onmouseover => 'eek()',
            class => 'none'
        )->push_content(
            HTML::Element->new(
                'span',
                id => 'n5',
                class => 'spanny',
                style => 'font-family: monospace',
                'data-analysis' => 'yes please',
            ),
        ),
    ),
);

$node->clean_element($elem);

is($elem->as_HTML, '<body><div><span><span style="font-family: monospace"></span></span></div></body>');

done_testing();
