package RSS::Tree::Item;

# Copyright 2013-2016 Sean McAfee

# This file is part of RSS::Tree.

# RSS::Tree is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# RSS::Tree is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with RSS::Tree.  If not, see <http://www.gnu.org/licenses/>.

use RSS::Tree::HtmlDocument;
use strict;


sub new {
    my ($class, $parent, $item) = @_;
    bless { parent => $parent, item => $item }, $class;
}

sub title {
    return shift->{item}->title;
}

sub set_title {
    my ($self, $title) = @_;
    $self->{item}->title($title);
    return $self;
}

sub link {
    return shift->{item}->link;
}

sub set_link {
    my ($self, $link) = @_;
    $self->link($link);
    return $self;
}

sub author {
    return shift->{item}->author;
}

sub set_author {
    my ($self, $author) = @_;
    $self->{item}->author($author);
    return $self;
}

*creator = *author;
*set_creator = *set_author;

sub categories {
    return shift->category;
}

sub _uri {
    my $self = shift;
    return $self->{parent}->uri_for($self);
}

sub _ultimate_uri {
    my $self = shift;
    return $self->{ultimate_uri} ||= $self->_get_ultimate_uri;
}

sub _get_ultimate_uri {
    my $self = shift;
    return $self->{parent}->agent->head($self->_uri)->base->as_string;
}

sub uri {
    my ($self, $other_uri, $follow) = @_;
    require URI;
    if (defined $other_uri) {
        my $base = $follow ? $self->_ultimate_uri : $self->_uri;
        return URI->new_abs($other_uri, $base);
    } else {
        return URI->new($self->_uri);
    }
}

sub description {
    my $self = shift;
    $self->{description} = $self->_new_page($self->{item}->content->body)
        if !exists $self->{description};
    return $self->{description};
}

sub page {
    my $self = shift;
    $self->{page} = do {
        my $parent = $self->{parent};
        my $uri    = $self->_uri;
        $self->_new_page(sub { $parent->_download_item($uri) }, $uri);
    } if !exists $self->{page};
    return $self->{page};
}

*content = *description;

sub cache {
    my $self = shift;
    return $self->{cache} ||=
        $self->{parent}{cache}->_item_cache($self)
            || die "Item cacheing is not available\n";
}

sub _new_page {
    my ($self, $content, $uri) = @_;
    return RSS::Tree::HtmlDocument->new($uri || $self->uri, $content);
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

=item $item->unwrap

=back

Returns the wrapped C<XML::RSS> item, an unblessed hash reference.
See that class's documentation for details.

=over 4

=item $item->title
=item $item->link
=item $item->guid
=item $item->author
=item $item->creator
=item $item->categories

=back

These methods return the corresponding fields of the underlying
C<XML::RSS> item, except for the C<categories> method, which returns a
list of the underlying item's categories instead of returning the
field (which may be a string or an array reference) directly.

=over 4

=item $item->set_title($new_title)
=item $item->set_link($new_link)
=item $item->set_guid($new_guid)
=item $item->set_author($new_author)
=item $item->set_creator($new_creator)
=item $item->set_categories(@new_categories)

=back

These methods set the corresponding fields of the underlying
C<XML::RSS> item and return C<$item>.  For all but C<set_categories>,
if the first argument is missing or C<undef>, then that field is
deleted from the item.

=over 4

=item $item->uri([ $other_uri [, $follow ] ])

If C<$other_uri> is undefined, returns a C<URI> object for the page
linked to by this item.  The link may not be the same as this object's
C<link> field if this object's parent C<RSS::Tree> object has
overloaded its C<uri_for> method.

Otherwise, returns a new absolute C<URI> object formed by taking the
provided C<$other_uri>, relative to a base URI.  If C<$follow> is
false, then that base URI is this item's URI.  Otherwise, the base URI
is obtained by issuing a HEAD request for this item's URI and using
the URI of the final request, after any redirections have occurred.
This base URI is cached so that further calls to this method with a
true C<$follow> parameter do not result in repeated HEAD requests
being issued.

=item $item->description
=item $item->content

These methods return a C<RSS::Tree::HtmlDocument> object which wraps
the value of this item's "description" and "content" fields,
respectively.

=item $item->page

Returns a C<RSS::Tree::HtmlDocument> object which wraps the HTML page
linked to by this item.

=item $item->cache

Returns a reference to a hash which is tied to this item's cache store
in its originating tree.  That cache store is used to save the
rendered version of this item's content; the hash returned by this
method hooks into a separate store for arbitrary user-defined data.

If item cacheing is not enabled (that is, if the C<RSS::Tree> object
that generated this item does not have appropriately-set C<cache_dir>
and C<item_cache_seconds> parameters), an exception is raised.

The hash returned by this method is tied an implementation that
supports only the C<STORE> and C<FETCH> operations.  An exception will
be raised if any other hash operation is attempted.

=back
