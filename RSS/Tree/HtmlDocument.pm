package RSS::Tree::HtmlDocument;

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

use Scalar::Util;
use URI;
use overload '""' => '_as_str', fallback => 1;
use strict;


sub new {
    my ($class, $uri, $content) = @_;
    my $delayed = !Scalar::Util::blessed($content) && ref $content eq 'CODE';
    $content = "$content" if !$delayed;

    if (defined $uri) {
        $uri = URI->new($uri);
        defined $uri->scheme
            or die "Cannot construct ", __PACKAGE__, " object with a relative URI\n";
    }

    bless {
        uri     => $uri,
        content => $content,
        delayed => $delayed,
        exposed => undef,
    }, $class;

}

sub uri {
    my $uri = shift->{uri};
    return $uri && $uri->clone;
}

sub absolute_uri {
    my ($self, $uri) = @_;

    $uri = URI->new($uri);
    return $uri if defined $uri->scheme;

    defined $self->{uri}
        or die "Cannot convert relative URI to absolute URI; this ",
               ref $self, " object was not constructed with a URI\n";

    return URI->new_abs($uri, $self->{uri});

}

sub guts {
    return shift->_tree->guts;
}

sub find {
    my ($self, $path, @classes) = @_;
    return _find_all($self->_tree, $path, @classes);
}

sub remove {
    my ($self, $path, @classes) = @_;
    _remove($self->_tree, $path, @classes);
    return $self;
}

sub truncate {
    my ($self, $path, @classes) = @_;
    _truncate($self->_tree, $path, @classes);
    return $self;
}

sub _content {
    my $self = shift;
    if ($self->{delayed}) {
        $self->{content} = "" . $self->{content}->();
        $self->{delayed} = undef;
    }
    return $self->{content};
}

sub _tree {
    my $self = shift;
    return $self->{tree} ||= do {
        require HTML::TreeBuilder::XPath;
        my $tree = HTML::TreeBuilder::XPath->new(ignore_unknown => 0);
        $tree->parse($self->_content);
        $tree->eof;
        $self->{exposed} = 1;
        $tree;
    };
}

sub _as_str {
    my $self = shift;
    return $self->{exposed} ? _render_tree($self->_tree) : $self->_content;
}

sub _render_tree {
    my $tree = shift;
    return _render($tree->guts);
}

sub _render {
    return join "", map {
        Scalar::Util::blessed($_) && $_->isa('HTML::Element')
            ? $_->as_HTML("", undef, { })
            : $_
    } @_;
}

sub _format_path {
    my ($path, @classes) = @_;
    return sprintf $path, map _has_class($_), @classes;
}

sub _has_class {
    my $class = shift;
    return sprintf 'contains(concat(" ",normalize-space(@class)," ")," %s ")',
                   $class;
}

sub _remove {
    $_->detach for _find_all(@_);
}

sub _truncate {
    for my $node (_find_all(@_)) {
        my $parent = $node->parent;
        $parent->splice_content($node->pindex) if $parent;
    }
}

sub _find_all {
    my ($context, $path, @classes) = @_;
    return $context->findnodes(_format_path($path, @classes));
}

1;

__END__

=head1 NAME

RSS::Tree::HtmlDocument - Wrapper for an HTML document, or a fragment of one

=head1 SYNOPSIS

    my @elements = $document->guts;

    my @paragraphs = $document->find('//p');

    my @summaries = $document->find('//div[%s]', 'summary');

    $document->remove('//script');

    $document->truncate('//div[@id="comment-divider"]');

    print "My document: $document";  # stringification

=head1 DESCRIPTION

A C<RSS::Tree::HtmlDocument> object wraps an HTML fragment which is
parsed on demand into a tree by the C<HTML::TreeBuilder::XPath>
module, and provides views into the document tree via an enhanced
version of that class's C<findnodes> method.

=head1 CONSTRUCTOR

=over 4

=item RSS::Tree::HtmlDocument->new($uri, $content)

Creates a new C<RSS::Tree::HtmlDocument> object which wraps the
content C<$content>.  If C<$content> is an unblessed code reference,
it will be called to generate the actual content the first time it is
needed.

The wrapped content will be converted into a string, if it is not a
string to begin with.

C<$uri> is the URI associated with this object.  It may be C<undef>,
but otherwise it must be an absolute URI, or an exception will be
thrown.

=head1 METHODS

=over 4

=item $doc->uri

Returns a copy of the URI with which this object was initialized (as
an instance of the class C<URI>), or C<undef> if this object has no
URI.

=item $doc->absolute_uri($uri)

Returns a new absolute URI for C<$uri>.  If C<$uri> is already an
absolute URI, a new C<URI> object initialized from it is returned.
Otherwise, this object's URI is used as a base to convert C<$uri> into
an absolute URI--again, as a new C<URI> object.  An exception is
thrown if this cannot be done because this object was not initialized
with its own URI.

=item $doc->guts

Calling this method causes the enclosed HTML fragment to be parsed
into a tree structure by the C<HTML::TreeBuilder::XPath> class, if it
has not already been so parsed, and returns the result of calling the
C<guts> method on that tree.  See that class for more details,
particularly the difference between scalar and list context.

=item $doc->find($xpath [, @classes ])

This method causes the enclosed HTML fragment to be parsed into a tree
of nodes by the C<HTML::TreeBuilder::XPath> class, if it has not
already been so parsed, and forwards the given XPath expression to the
C<findnodes> method of the tree's root node; see that class's
documentation for details.  The scalar or list context of the call to
this method is propagated to the root node's C<findnodes> method.

In dealing with HTML, one often wants to select nodes whose C<class>
attribute contains a given word.  Doing this properly requires an
inconveniently lengthy XPath test:

    contains(concat(" ",normalize-space(@class)," ")," desired-class ")

To relieve clients of the job of writing this test over and over,
C<"%s"> character sequences in the XPath expression are expanded into
instances of this test if additional arguments are supplied to this
method.  Each additional argument is expanded into the above string,
where the argument's value replaces C<"desired-class">, and C<"%s">
sequences in C<$xpath> are replaced with these strings in the order
that they occur.  For example, the first argument in this call:

    $document->find('//div[%s]/div[%s]', 'header', 'subheader')

...is expanded into the following XPath expression:

    //div[contains(concat(" ",normalize-space(@class)," ")," header ")]/
      div[contains(concat(" ",normalize-space(@class)," ")," subheader ")]

This substitution is performed by a simple call to C<sprintf>, so any
extra arguments are discarded, and any extra C<"%s"> sequences are
deleted.

=item $doc->remove($xpath [, @classes ])

Removes all elements matching C<$xpath> and C<@classes>, using the
same element-finding functionality as the C<find> method, above.
Returns C<$doc>.

=item $doc->truncate($xpath [, @classes ])

Removes all elements matching C<$xpath> and C<@classes>, using the
same element-finding functionality as the C<find> method, above, as
well as the following sibling elements of each.  Returns C<$doc>.

=back

This class provides convenient stringification logic.  Until one of
the C<guts>, C<find>, C<remove>, or C<truncate> methods are called, an
object of this class stringifies to exactly the HTML text that it was
initialized with.  The aforementioned methods expose the tree
structure of the wrapped HTML fragment.  The stringification of this
object is intended to reflect changes to the tree structure, and so
after any of those methods have been called, the object stringifies to
the concatenation of all of the nodes returned by the tree's C<guts>
method (see C<HTML::TreeBuilder>).  C<HTML::Element> objects in this
node list are stringified by calling that classes's C<as_HTML> method;
other nodes are stringified in the default manner.

For example, consider an object C<$doc> of this class that wraps the
following HTML fragment:

    <div id='main'>
      <span id='one'>One</span>
      <span id='two'>Two</span>
    </div>

Then the following code:

    $doc->remove('//span[@id="one"]');
    print $doc;

...will print "<div><span id='two'>Two</span></div>" (possibly modulo
whitespace).
