# -*- perl -*-
use RSS::Tree;
use Test::More;
use XML::RSS;
use strict;

delete $ENV{RSS_TREE_CACHE_DIR};


done_testing();

sub run_tree {
    my ($tree, $name) = @_;
    return map { $_->{description} }
             @ { XML::RSS->new->parse($tree->run($name))->{items} };
}


BEGIN {

package NumericTree;

our @ISA = qw(TestTree);

sub new {
    my $class = shift;
    return $class->SUPER::new('odd', 'odd', @_);
}

sub init {
    my $self = shift;
    $self->add(
        NumericTree::Even->new('even', 'even'),
    );
}

sub test {
    my ($self, $item) = @_;
    return $item->description =~ /^\d+\z/;
}

}

BEGIN {

package NumericTree::Even;

our @ISA = qw(RSS::Tree::Node);

sub test {
    my ($self, $item) = @_;
    return $item->description % 2 == 0;
}

}
