package Snopes;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://www.snopes.com/info/whatsnew.rss',
    NAME  => 'snopes',
    TITLE => 'Snopes',
};

#
#  For Snopes, I render the item as it normally appears, but I prepend
#  the "Verdict," found by reaching into the associated page content.
#  I don't want to bother loading and reading pages where the verdict
#  is unsurprising or common-sensical.
#

sub render {
    my ($self, $item) = @_;
    my @verdict;

    if (my ($divider) = $item->page->find('//img[contains(@src,"content-divider")]')) {
        my ($verdict) = $divider->parent->right->as_text =~ /(\w+)/;
        @verdict = $self->new_element(
            'p', 'Verdict: ', $verdict ? [ 'b', $verdict ] : [ 'i', 'not found' ]
        );
    }

    return (@verdict, $self->SUPER::render($item));

}

1;
