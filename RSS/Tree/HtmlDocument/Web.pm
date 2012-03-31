package RSS::Tree::HtmlDocument::Web;

use base qw(RSS::Tree::HtmlDocument);
use strict;


sub _get_content {
    my $self = shift;
    require LWP::Simple;
    defined(my $content = LWP::Simple::get($self->{uri}))
        or die "Failed to download URL $self->{url}\n";
    return $content;
}


1;
