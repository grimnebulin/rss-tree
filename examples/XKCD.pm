package XKCD;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://xkcd.com/rss.xml',
    NAME  => 'xkcd',
    TITLE => 'XKCD',
};

#
#  XKCD comics always have amusing mouseover text, stored in the comic
#  image's "title" attribute.  But I'd rather just see the comment in
#  my feed reader, without having to mouse over the image:
#

sub render {
    my ($self, $item) = @_;

    if (my ($image) = $item->description->find('//img')) {
        $image->postinsert(
            $self->new_element('p', [ 'i', $image->attr('title', undef) ])
        );
    }

    return;

}


1;
