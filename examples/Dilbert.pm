package Dilbert;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://feeds.feedburner.com/DilbertDailyStrip?format=xml',
    NAME  => 'dilbert',
    TITLE => 'Dilbert',
    KEEP_GUID => 1,
};

#
#  Rendering is simple: Find the image on the referenced page,
#  and return it.
#

sub render {
    my ($self, $item) = @_;
    my ($img) = $item->page->find('//div[%s]/img', 'STR_Image') or return;
    return $img;
}

#
#  The URI for the referenced page is stored in the item's "guid"
#  field, for some reason.
#

sub uri_for {
    my ($self, $item) = @_;
    return $item->guid;
}

#
#  The dilbert.com web site returns an HTTP header "Content-Type:
#  text/html; charset=utf-8lias".  The weird charset makes the page
#  content undecodable in the default manner.  (It is for this sin
#  that I'm using the feed as an example of how to reach into the
#  site and extract content of interest, avoiding ads.)
#
#  The problem is easily surmountable; we simply override the
#  decode_response method to decode the content in a way that works.
#

sub decode_response {
    my ($self, $response) = @_;
    return $response->decoded_content(alt_charset => 'utf-8');
}



1;
