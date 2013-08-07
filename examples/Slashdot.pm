package Slashdot;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://rss.slashdot.org/Slashdot/slashdot',
    NAME  => 'slashdot',
    TITLE => 'Slashdot',
};

#
#  One of the simplest, yet most useful rendering routines: simply
#  reach into the page linked to by the item, and extract the single
#  element that contains the content of interest.
#

sub render {
    my ($self, $item) = @_;
    return $item->page->find('//div[%s]', 'body');
}


1;
