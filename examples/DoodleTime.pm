package DoodleTime;

use parent qw(RSS::Tree);
use strict;

use constant {
    NAME  => 'doodletime',
    TITLE => 'Doodle Time',
    FEED  => 'http://sarahseeandersen.tumblr.com/rss',
};

#
#  This is pretty simple: I only want to see the items with comics,
#  which, it turns out, conveniently include a category "comics".
#

sub init {
    shift->match_category('comic');
}


1;
