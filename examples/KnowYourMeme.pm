package KnowYourMeme;

use parent qw(RSS::Tree);
use strict;

use constant {
    NAME     => 'knowyourmeme',
    TITLE    => 'Know Your Meme',
    FEED     => 'http://knowyourmeme.com/memes.rss',
    # Agents that don't provide an agent ID get 403 FORBIDDEN, so:
    AGENT_ID => 'Anything',
};

#
#  Items in this feed are heavily footnoted, with the footnotes
#  provided in a <div> element with the class "references".  I don't
#  want to have to be constantly skipping back and forth while
#  reading, so this render method replaces footnote references with
#  the corresponding footnote content.
#

sub render {
    my ($self, $item) = @_;

    my ($refs) = $item->description->find('//div[%s]', 'references') or return;
    my %ref;

    for my $para ($self->find($refs, 'p[starts-with(@id,"fn")]')) {
        $self->remove($para, 'sup');
        $ref{ $para->attr('id') } = $para;
    }

    $refs->detach;
    $item->description->truncate('//h2[string()="External References"]');

    for my $link ($item->description->find('//a[starts-with(@href,"#fn")]')) {
        my $id = substr $link->attr('href'), 1;
        if (exists $ref{$id}) {
            $link->replace_with('[', $ref{$id}->content_list, ']');
        }
    }

    return;

}


1;
