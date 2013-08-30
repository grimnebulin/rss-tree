package ComicsCurmudgeon;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://feeds.feedburner.com/joshreads',
    NAME  => 'comicscurmudgeon',
    TITLE => 'The Comics Curmudgeon',
};

#
#  Every Friday, the Comics Curmudgeon posts a summary of the previous
#  week's activity in an item with a title starting with "Metapost:".
#  In these items, there are a number of paragraphs, each commenting
#  on a comic strip mentioned in the previous week, each with a
#  hyperlink to the strip in question.  Rather than having to click
#  through, I'd rather just slurp the referenced image directly into
#  the item.  The hyperlink thereupon becomes unnecessary, so I
#  replace it with bolded text.
#

sub render {
    my ($self, $item) = @_;

    if ($item->title =~ /Metapost/) {
        for my $link ($item->content->find('//p/a[contains(@href,"/images/")]')) {
            $link->parent->postinsert(
                $self->new_element('p', [ 'img', { src => $link->attr('href') } ])
            );
            $link->replace_with($self->new_element('b', $link->content_list));
        }
    }

    return;

}


1;
