package RSS::Tree::Item;

use URI;
use strict;


sub new {
    my ($class, $parent, $item) = @_;
    bless { parent => $parent, item => $item }, $class;
}

sub title {
    return shift->{item}{title};
}

sub link {
    return shift->{item}{link};
}

sub guid {
    return shift->{item}{guid};
}

sub author {
    return shift->{item}{author};
}

sub creator {
    return shift->{item}{dc}{creator};
}

sub categories {
    my $cat = shift->{item}{category};
    return ref $cat ? @$cat : $cat;
}

sub _uri {
    my $self = shift;
    return $self->{parent}->uri_for($self);
}

sub uri {
    my $self = shift;
    require URI;
    return @_ ? URI->new_abs($_[0], $self->_uri) : URI->new($self->_uri);
}

# It's not really clear that this method is still necessary...

sub absolutize {
    my ($self, $element, @attr) = @_;

    my @uri = map {
        my $uri = $self->uri($element->attr($_));
        $element->attr($_, $uri->as_string);
        $uri;
    } @attr;

    return wantarray ? @uri : $uri[0];

}

sub description {
    my $self = shift;
    return exists $self->{description}
        ? $self->{description}
        : ($self->{description} = $self->_static($self->{item}{description}));
}

sub page {
    my $self = shift;
    return exists $self->{page}
        ? $self->{page}
        : ($self->{page} = $self->_web($self->_uri));
}

sub content {
    my $self = shift;
    exists $self->{content} or $self->{content} = do {
        my $content = $self->{item}{content};
        $content = $content->{encoded}
            if ref $content eq 'HASH' && exists $content->{encoded};
        $self->{content} = defined $content ? $self->_static($content) : undef;
    };
    return $self->{content};
}

sub _static {
    my ($self, $content) = @_;
    require RSS::Tree::HtmlDocument;
    return RSS::Tree::HtmlDocument->new(
        $self->uri, $self->{parent}, $content
    );
}

sub _web {
    my ($self, $url) = @_;
    require RSS::Tree::HtmlDocument::Web;
    return RSS::Tree::HtmlDocument::Web->new(
        $self->uri($url), $self->{parent}
    );
}

1;

__END__

=head1 NAME

RSS::Tree::Item - Represents a single item from an RSS feed

=head1 SYNOPSIS

    # Simple accessors:

    my $title   = $item->title;
    my $link    = $item->link;
    my $guid    = $item->guid;
    my $author  = $item->author;
    my $creator = $item->creator;

    my $uri = $item->uri;
    my $newuri = $item->uri($relative_uri);

    my @anchors = $item->description->find('//a');
    my @divs    = $item->content->find('//div');

=head1 DESCRIPTION

A C<RSS::Tree::Item> is a wrapper around a single RSS item as produced
by the C<XML::RSS> class.  It provides simple accessors as well as
methods that return HTML tree views of the item's description and
content, as well as of the web page linked to by the item.

=head1 METHODS

=head2 SIMPLE ACCESSORS

=over 4

=item $item->title
=item $item->link
=item $item->guid
=item $item->author
=item $item->creator

=back

These methods return the corresponding field of the underlying
C<XML::RSS> item.

=over 4

=item $item->uri([ $relative_uri ])

Without an argument, returns a C<URI> object for the page linked to by
this item.  With an argument, returns a C<URI> object formed by using
the provided C<$relative_url>, relative to this item's URI.

=item $item->description
=item $item->content

These methods returns a C<RSS::Tree::HtmlDocument> object which wrap
the value of this item's "description" and "content" fields,
respectively.

=item $item->page

Returns a C<RSS::Tree::HtmlDocument::Web> object which wraps the HTML
page linked to by this item.

=back
