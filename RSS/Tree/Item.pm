package RSS::Tree::Item;

# Copyright 2013 Sean McAfee

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

use strict;


sub new {
    my ($class, $parent, $item) = @_;
    bless { parent => $parent, item => $item }, $class;
}

sub unwrap {
    return $_[0]{item};
}

sub title {
    return $_[0]{item}{title};
}

sub set_title {
    defined $_[1] ? ($_[0]{item}{title} = $_[1]) : delete $_[0]{item}{title};
    return $_[0];
}

sub link {
    return $_[0]{item}{link};
}

sub set_link {
    defined $_[1] ? ($_[0]{item}{link} = $_[1]) : delete $_[0]{item}{link};
    return $_[0];
}

sub guid {
    return $_[0]{item}{guid};
}

sub set_guid {
    defined $_[1] ? ($_[0]{item}{guid} = $_[1]) : delete $_[0]{item}{guid};
    return $_[0];
}

sub author {
    return $_[0]{item}{author};
}

sub set_author {
    defined $_[1] ? ($_[0]{item}{author} = $_[1]) : delete $_[0]{item}{author};
    return $_[0];
}

sub creator {
    return $_[0]{item}{dc}{creator};
}

sub set_creator {
    defined $_[1] ? ($_[0]{item}{dc}{creator} = $_[1]) : delete $_[0]{item}{dc}{creator};
    return $_[0];
}

sub categories {
    my $cat = shift->{item}{category};
    return ref $cat ? @$cat : $cat;
}

sub set_categories {
    my ($self, @newval) = @_;
    $self->{item}{category} = @newval != 1 ? \@newval : $newval[1];
    return $self;
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

=item $item->uri([ $relative_uri ])

Without an argument, returns a C<URI> object for the page linked to by
this item.  The link may not be the same as this object's C<link>
field if this object's parent C<RSS::Tree> object has overloaded its
C<uri_for> method.

With an argument, returns a C<URI> object formed by using the provided
C<$relative_url>, relative to this item's URI.

=item $item->description
=item $item->content

These methods return a C<RSS::Tree::HtmlDocument> object which wraps
the value of this item's "description" and "content" fields,
respectively.

=item $item->page

Returns a C<RSS::Tree::HtmlDocument::Web> object which wraps the HTML
page linked to by this item.

=back
