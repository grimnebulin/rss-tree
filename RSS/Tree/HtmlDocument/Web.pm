package RSS::Tree::HtmlDocument::Web;

use parent qw(RSS::Tree::HtmlDocument);
use strict;


sub _get_content {
    my $self = shift;
    defined(my $content = $self->{downloader}->download($self->{uri}))
        or die "Failed to download URL $self->{uri}\n";
    return $content;
}


1;

__END__

=head1 NAME

RSS::Tree::HtmlDocument::Web - wraps an HTML page that is downloaded on demand

=head1 DESCRIPTION

This class is a trivial subclass of C<RSS::Tree::HtmlDocument> that
downloads HTML content on demand rather than being initialized with
static HTML.
