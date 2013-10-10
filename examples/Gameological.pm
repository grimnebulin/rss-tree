package Gameological;

use parent qw(RSS::Tree);
use strict;

use constant {
    FEED  => 'http://gameological.com/feed/',
    NAME  => 'gameo',
    TITLE => 'Gameological',
};

#
#  For the Gameological feed, I want to separate out "Sawbuck Gamer"
#  items into two separate feeds: one for iOS games, and one for other
#  platforms.
#


sub init {
    my $self = shift;
    $self->add(
        RSS::Tree::Node->new('sawbuck', 'Sawbuck Gamer (Other)')
                       ->match_title('Sawbuck Gamer')
                       ->add(
            IosGames->new('sawbuckios', 'Sawbuck Gamer (iOS)')
        ),
    );
}

{

package IosGames;

use parent qw(RSS::Tree::Node);

#
#  Items about iOS games are identifiable by words like "iPhone" and
#  "iPad" in a <p class="metadata"> element on the linked-to web page.
#  We can make this determination by calling $item->page->find, but
#  doing so every time the test method is called would be excessive.
#  Instead, we cache the result of the check.  That way, we check the
#  page content only as often as we would download it anyway to render
#  it (once per day, by default).
#

sub test {
    my ($self, $item) = @_;
    my $ios = $item->cache->{is_ios} ||= do {
        my ($meta) = $item->page->find('//p[%s]', 'metadata');
        $meta && $meta->as_trimmed_text =~ /iP/ ? 'yes' : 'no';
    };
    return $ios eq 'yes';
}

}

1;
