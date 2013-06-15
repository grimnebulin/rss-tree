package RSS::Tree::HtmlDocument;

use URI;
use overload '""' => '_as_str', fallback => 1;
use strict;


sub new {
    my ($class, $uri, $downloader, $content) = @_;
    bless {
        uri        => $uri,
        downloader => $downloader,
        exposed    => undef,
        @_ >= 4 ? (content => $content) : (),
    }, $class;
}

sub find {
    my ($self, $path, @classes) = @_;
    $self->{exposed} = 1;
    return _find_all($self->_tree, $path, @classes);
}

sub open {
    my ($self, $uri) = @_;
    require RSS::Tree::HtmlDocument::Web;
    return RSS::Tree::HtmlDocument::Web->new(
        URI->new_abs($uri, $self->{uri}), $self->{downloader}
    );
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
    exists $self->{content} or $self->{content} = $self->_get_content;
    return $self->{content};
}

sub _tree {
    my $self = shift;
    return $self->{tree} ||= do {
        require HTML::TreeBuilder::XPath;
        my $tree = HTML::TreeBuilder::XPath->new(ignore_unknown => 0);
        $tree->parse($self->_content);
        $tree->eof;
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
        UNIVERSAL::isa($_, 'HTML::Element')
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

    my @paragraphs = $document->find('//p');

    my @summaries = $document->find('//div[%s]', 'summary');

    print "My document: $document";  # stringification

=head1 DESCRIPTION

A C<RSS::Tree::HtmlDocument> object wraps an HTML fragment which is
parsed on demand into a tree by the C<HTML::TreeBuilder::XPath>
module, and provides views into the document tree via an enhanced
version of that class's C<findnodes> method.

Objects of this class are not meant to be instantiated directly by
client code, so the class's constructor is not documented here.

=head1 METHODS

=over 4

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

=item $doc->open($uri)

Returns a new C<RSS::Tree::HtmlDocument::Web> object that refers to
the given URI.  If C<$uri> is a relative URI, it is taken to be
relative to the URI of this document.

=back

This class provides convenient stringification logic.  Until the
C<find> method is called, an object of this class stringifies to
exactly the HTML text that it was initialized with.  The C<find>
method exposes the tree structure of the wrapped HTML fragment; using
the returned nodes, client code is able to add nodes to the tree and
delete and rearrange existing nodes.  The stringification of this
object is intended to reflect such changes, and so after the C<find>
method has been called, the object stringifies to the concatenation of
all of the nodes returned by the tree's C<guts> method (see
C<HTML::TreeBuilder>).  C<HTML::Element> objects in this node list are
stringified by calling the C<as_HTML> method; text nodes are
stringified as-is.

For example, consider an object C<$doc> of this class that wraps the
following HTML fragment:

    <div id='main'>
      <span id='one'>One</span>
      <span id='two'>Two</span>
    </div>

Then the following code:

    $doc->find('//span[@id="one"]')->shift->detach;
    print $doc;

...will print "<div><span id='two'>Two</span></div>" (possibly modulo
whitespace).

=head1 SEE ALSO

L<RSS::Tree::HtmlDocument::Web>
