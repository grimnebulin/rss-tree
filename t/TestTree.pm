package TestTree;

use TestAgent;
use XML::RSS;
use parent qw(RSS::Tree);
use strict;

sub new {
    my ($class, $name, $title, @items) = @_;
    return $class->SUPER::new(
        name  => $name,
        title => $title,
        feed  => 'test://test',
        agent => TestAgent->new(@items),
    );
}

sub run_test {
    my ($self, $name) = @_;
    return map { $_->{description} }
             @ { XML::RSS->new->parse($self->run($name))->{items} };
}


1;
