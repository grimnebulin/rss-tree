package RSS::Tree::HtmlDocument::Static;

use base qw(RSS::Tree::HtmlDocument);
use strict;


sub new {
    my ($class, $uri, $downloader, $content) = @_;
    return $class->SUPER::new($uri, $downloader, $content);
}


1;
