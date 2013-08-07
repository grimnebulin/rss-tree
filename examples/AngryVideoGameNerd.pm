package AngryVideoGameNerd;

use parent qw(RSS::Tree);
use strict;

use constant {
    NAME  => 'avgn',
    TITLE => 'AVGN',
    FEED  => 'http://feeds2.feedburner.com/Cinemassacrecom',
};


#
#  Nothing fancy here.  We just remove ad-related elements from the
#  item's original content.
#
#  Virtually all of the RSS content is links to videos which are more
#  conveniently viewed by clicking through to the site, so I don't
#  feel bad about showing how to strip the ads in the feed itself.
#

sub render {
    my ($self, $item) = @_;
    return $item->description->remove(
        '//p[.//a[contains(@href,"doubleclick")]]|//div[%s]', 'feedflare'
    );
}


1;
