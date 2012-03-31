package RSS::Tree::HtmlDocument::Static;

use base qw(RSS::Tree::HtmlDocument);
use strict;


sub new {
    my ($class, $uri, $content) = @_;
    return $class->SUPER::new($uri, content => $content);
}


1;
