package RSS::Tree::HtmlDocument::Web;

use base qw(RSS::Tree::HtmlDocument);
use strict;


sub _get_content {
    my $self = shift;
    defined(my $content = $self->{downloader}->_download($self->{uri}))
        or die "Failed to download URL $self->{url}\n";
    return $content;
}


1;
