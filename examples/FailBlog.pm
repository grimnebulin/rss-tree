package FailBlog;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://feeds.feedburner.com/failblog',
    NAME  => 'failblog',
    TITLE => 'Fail Blog',
};

#
#  For the FailBlog feed, I want to separate out the items with videos
#  into a separate feed:
#

sub init {
    my $self = shift;
    $self->add(FailBlogVideo->new('failblogvideo', 'Fail Blog Video'));
}

#
#  Oh, and also, I don't want to see items with titles that include
#  the string "Mini Clip Show":
#

sub test {
    my ($self, $item) = @_;
    return $item->title !~ /Mini Clip Show/;
}


#
#  The test for whether an item contains a video is more complicated
#  than a simple regular expression match against an item's title,
#  author, creator, or categories, so we need to define a subclass of
#  RSS::Tree::Node to do the job.
#

package FailBlogVideo;

use parent qw(RSS::Tree::Node);

sub test {
    my ($self, $item) = @_;
    return $item->content->find('//param|//iframe')->size > 0;
}


1;
