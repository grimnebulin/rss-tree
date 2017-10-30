package TestAgent;

use HTTP::Response;
use XML::RSS;
use strict;


sub new {
    my ($class, @items) = @_;
    bless \@items, $class;
}

sub get {
    my ($self, $url) = @_;
    return HTTP::Response->new(200, undef, [], $self->_make_rss);
}

sub _make_rss {
    my $self = shift;

    my $rss = XML::RSS->new(version => '2.0');

    $rss->channel(
        title       => 'test',
        link        => 'test://link',
        description => 'test',
    );

    for my $item (@$self) {
        $rss->add_item(
            link        => 'test://item',
            title       => 'test',
            description => $item,
        );
    }

    return $rss->as_string;

}


1;
