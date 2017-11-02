#!/usr/bin/perl

use File::Spec;
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
