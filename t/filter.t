# -*- perl -*-
use Test::More;
use lib './t';
use strict;


delete $ENV{RSS_TREE_CACHE_DIR};

my $tree = NumericTree->new(qw(foo bar baz), 0 .. 10, 'a' .. 'z');

my @items = $tree->run_test('even');

is_deeply(\@items, [ 0, 2, 4, 6, 8, 10 ]);

@items = $tree->run_test('odd');

is_deeply(\@items, [ 1, 3, 5, 7, 9 ]);


$tree = MonsterTree->new('a' .. 'm', 0 .. 49, 'n' .. 'z', 50 .. 99);

@items = $tree->run_test('root');

is_deeply(\@items, [ 'a' .. 'z' ]);

@items = $tree->run_test('numeric');

is(@items, 0);

for my $tens (0 .. 9) {
    @items = $tree->run_test('T' . $tens);
    is_deeply(\@items, [ map { 10 * $tens + $_ } 6 .. 9 ]);
    for my $ones (0 .. 9) {
        @items = $tree->run_test('O' . $tens . $ones);
        is_deeply(\@items, $ones < 6 ? [ 10 * $tens + $ones ] : [ ]);
    }
}

done_testing();

########################################


BEGIN {

package NumericTree;

use parent qw(TestTree);

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

use parent qw(RSS::Tree::Node);

sub test {
    my ($self, $item) = @_;
    return $item->description % 2 == 0;
}

}

BEGIN {

package MonsterTree;

use parent qw(TestTree);

sub new {
    my $class = shift;
    return $class->SUPER::new('root', 'root', @_);
}

sub init {
    shift->add(MonsterTree::NumericNode->new);
}

}

BEGIN {

package MonsterTree::NumericNode;

use parent qw(RSS::Tree::Node);

sub new {
    return shift->SUPER::new('numeric', 'numeric')->add(
        map { MonsterTree::TensNode->new($_) } 0 .. 9
    );
}

sub test {
    my ($self, $item) = @_;
    return $item->description =~ /^\d+\z/;
}

}

BEGIN {

package MonsterTree::TensNode;

use parent qw(RSS::Tree::Node);

sub new {
    my ($class, $tens_digit) = @_;
    my $name = 'T' . $tens_digit;
    my $self = $class->SUPER::new($name, $name)->add(
        map { MonsterTree::OnesNode->new($tens_digit, $_) } 0 .. 5
    );
    $self->{digit} = $tens_digit;
    return $self;
}

sub test {
    my ($self, $item) = @_;
    return $item->description < 10 * ($self->{digit} + 1);
}

}

BEGIN {

package MonsterTree::OnesNode;

use parent qw(RSS::Tree::Node);

sub new {
    my ($class, $tens_digit, $ones_digit) = @_;
    my $name = 'O' . $tens_digit . $ones_digit;
    my $self = $class->SUPER::new($name, $name);
    $self->{digit} = $ones_digit;
    return $self;
}

sub test {
    my ($self, $item) = @_;
    return $item->description % 10 == $self->{digit};
}

}
