#!/usr/bin/perl

use Cwd;
use File::Spec;
use RSS::Tree;
use TestAgent;
use Test::More;
use XML::Feed;
use strict;

my $BASE_URL = 'http://rss.tree.test/test/';

# Basic test

eval { RSS::Tree->new->run };
like($@, qr/No RSS feed defined/);

my $agent = TestAgent->new(File::Spec->catfile(Cwd::getcwd, 'feeds'), $BASE_URL);

# Hey, if root node has no name, shit fails!

my $tree = RSS::Tree->new(
    agent => $agent,
    feed  => "${BASE_URL}simple.xml",
    name => 'ROOT',
);

my @items;

my $feed = XML::Feed->parse(\$tree->run);
is($feed->items, 3);

#
#  Tree behavior
#

$tree->add(
    RSS::Tree::Node->new('one')->match_title('1'),
    RSS::Tree::Node->new('three')->match_title('3'),
);

$feed = XML::Feed->parse(\$tree->run);
@items = $feed->items;
is(@items, 1);
is($items[0]->title, 'Item 2');

$feed = XML::Feed->parse(\$tree->run('one'));
@items = $feed->items;
is(@items, 1);
is($items[0]->title, 'Item 1');

$feed = XML::Feed->parse(\$tree->run('three'));
@items = $feed->items;
is(@items, 1);
is($items[0]->title, 'Item 3');

$tree->clear;

{

package FailNode;

our @ISA = qw(RSS::Tree::Node);

sub test { 0 }
    
}

$tree->add(
    FailNode->new('A')->add(
        FailNode->new('B')->add(
            FailNode->new('C')->add(
                RSS::Tree::Node->new('D')->match_title('3'),
            ),
        ),
    ),
    FailNode->new('E')->add(
        RSS::Tree::Node->new('F')->match_title('1'),
        FailNode->new('G')->add(
            RSS::Tree::Node->new('H')->match_title('2'),
        ),
    ),
);

$feed = XML::Feed->parse(\$tree->run);
is($feed->items, 0);

$feed = XML::Feed->parse(\$tree->run('D'));
@items = $feed->items;
is(@items, 1);
is($items[0]->title, 'Item 3');

$feed = XML::Feed->parse(\$tree->run('F'));
@items = $feed->items;
is(@items, 1);
is($items[0]->title, 'Item 1');

$feed = XML::Feed->parse(\$tree->run('H'));
@items = $feed->items;
is(@items, 1);
is($items[0]->title, 'Item 2');

for my $name (qw(A B C E G)) {
    print "name=$name\n";
    $feed = XML::Feed->parse(\$tree->run($name));
    print join(";", map $_->title, $feed->items), "\n";
    is($feed->items, 0);
}
