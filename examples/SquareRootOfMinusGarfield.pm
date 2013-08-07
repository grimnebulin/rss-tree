package SquareRootOfMinusGarfield;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://www.mezzacotta.net/garfield/rss.xml',
    NAME  => 'sromg',
    TITLE => 'Square Root of Minus Garfield',
    KEEP_GUID => 1,
};

#
#  The URI for the referenced page is stored in the item's "guid"
#  field, for some reason.
#

sub uri_for {
    my ($self, $item) = @_;
    return $item->guid;
}

#
#  Furthermore, items may have no "link" field at all, making it
#  impossible to jump to the associated page from a feed reader.  So
#  we postprocess the item by copying the "guid" field to the "link"
#  field if it doesn't have one.
#

sub postprocess_item {
    my ($self, $item) = @_;
    $item->set_link($item->guid) if !$item->link;
}

#
#  We render the item normally, but append the author's comments found
#  by reaching into the associated page.
#

sub render {
    my ($self, $item) = @_;

    my @comments = $item->page->find(
        '//p[contains(string(),"The author writes")]'
    );

    if (@comments) {
        splice @comments, 1;
        for my $sibling ($comments[0]->findnodes('following-sibling::*')) {
            last if $sibling->tag ne 'p';
            push @comments, $sibling;
        }
    }

    return ($self->SUPER::render($item), @comments);

}


1;
