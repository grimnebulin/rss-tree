package Geekologie;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://feeds.feedburner.com/geekologie/iShm',
    NAME  => 'geekologie',
    TITLE => 'Geekologie',
};

#
#  Geekologie items often begin with an image immediately followed by
#  text, which flows from the lower-right corner of the image rather
#  than underneath it.  That's annoying, so we wrap the first node of
#  the item's description in a <div>.
#
#  Also, these items have an amusing set of categories which are
#  normally not shown, so we prepend them to the item body in a
#  smaller font, separated by pipe characters.
#

sub render {
    my ($self, $item) = @_;

    my @guts = $item->description->guts;

    if (@guts) {
        $guts[0] = $self->new_element('div', $guts[0]);
    }

    if (my @categories = $item->categories) {
        unshift @guts, $self->new_element(
            'div', { style => 'font-size: smaller' }, join ' | ', @categories
        );
    }

    return @guts;

}


1;
