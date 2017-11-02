#!/usr/bin/perl

use File::Spec;
use File::Temp;
use RSS::Tree;
use Test::More;
use strict;

#
#  write_programs test
#

my $tree = RSS::Tree->new(name => 'root')->add(
    RSS::Tree::Node->new('child1')->add(
        RSS::Tree::Node->new('grandchild1'),
    ),
    RSS::Tree::Node->new('child2'),
);

my $dir = File::Temp->newdir;

sub found { -e File::Spec->catfile($dir, shift) }

$tree->write_programs(dir => $dir);

ok(found('root.pl'));
ok(found('child1.pl'));
ok(found('child2.pl'));
ok(found('grandchild1.pl'));

done_testing();
