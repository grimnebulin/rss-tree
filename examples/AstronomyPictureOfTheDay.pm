package AstronomyPictureOfTheDay;

use parent qw(RSS::Tree);
use strict;

use constant {
    NAME  => 'apod',
    TITLE => 'APOD',
    FEED  => 'http://antwrp.gsfc.nasa.gov/apod.rss',
};

#
#  Here we extract the interesting content from the referenced page,
#  replacing the feed's original content with it.  The task is
#  complicated slightly by the archaic page layout, with nary a
#  class or id attribute to hang on to.
#

sub render {
    my ($self, $item) = @_;
    my ($h1)  = $item->page->find('//h1') or return;
    my ($pic) = $h1->findnodes('following-sibling::p[last()]') or return;
    my $top   = $h1->parent;

    my ($tomorrow) = $top->findnodes(
        'following-sibling::*[contains(string(),"Tomorrow\'s picture")]'
    ) or return;

    my @text = ($top->parent->content_list)[
        $top->pindex + 1 .. $tomorrow->pindex - 1
    ];

    return ($pic, @text);
}


1;
