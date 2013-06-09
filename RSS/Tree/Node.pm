package RSS::Tree::Node;

use Carp ();
use RSS::Tree::HtmlDocument;
use Scalar::Util ();
use strict;


sub new {
    my ($class, $name, $title) = @_;

    !defined $name
        or $name =~ /^\w+\z/
        or Carp::croak(qq(Invalid node name "$name"\n));

    bless {
        name     => $name,
        title    => $title,
        parent   => undef,
        children => [ ],
        test     => undef,
    }, $class;

}

 sub name {
    return shift->{name};
}

sub title {
    return shift->{title};
}

sub parent {
    return shift->{parent};
}

sub root {
    my $self = shift;
    return $self->parent->root if $self->parent;
    return $self;
}

sub add {
    my $self = shift;
    push @{ $self->{children} }, @_;
    Scalar::Util::weaken($_->{parent} = $self) for @_;
    return $self;
}

sub test {
    my ($self, $item) = @_;
    return !$self->{test} || $self->{test}->($item);
}

sub match_title {
    return shift->_match('title', @_);
}

sub match_author {
    return shift->_match('author', @_);
}

sub match_creator {
    return shift->_match('creator', @_);
}

sub _match {
    my ($self, $field, $regex) = @_;
    $self->{test} = eval "sub { _trim(\$_[0]->$field) =~ /\$regex/o }";
    die $@ if $@;
    return $self;
}

sub handles {
    my ($self, $item, $stop) = @_;
    if ($self->test($item)) {
        for my $child ($self->_children) {
            my $node = $child->handles($item, $stop);
            return $node if $node || !defined $node;
        }
        return $self;
    }
    return if defined $stop && defined $self->{name} && $self->{name} eq $stop;
    return 0;
}

sub render {
    my ($self, $item) = @_;
    return $self->parent->render($item) if $self->parent;
    return $item->content if defined $item->content;
    return $item->description;
}

sub uri_for {
    my ($self, $item) = @_;
    return $item->link;
}

sub new_element {
    my $self = shift;
    require HTML::Element;
    return HTML::Element->new_from_lol([ @_ ]);
}

sub find {
    my ($self, $context, $path, @classes) = @_;
    return $context->findnodes(
        RSS::Tree::HtmlDocument::_path($path, @classes)
    );
}

sub remove {
    my ($self, $context, $path, @classes) = @_;
    RSS::Tree::HtmlDocument::_remove($context, $path, @classes);
    return $self;
}

sub truncate {
    my ($self, $context, $path, @classes) = @_;
    RSS::Tree::HtmlDocument::_truncate($context, $path, @classes);
    return $self;
}

sub _children {
    return @{ shift->{children} };
}

sub _write_program {
    my ($self, $tree_class, @use_class) = @_;

    $_->_write_program($tree_class, @use_class) for $self->_children;

    return if !defined $self->{name};

    my $filename = "$self->{name}.pl";

    open my $fh, '>', $filename
        or die "Can't open file $filename for writing: $!\n";

    print $fh "#!/usr/local/bin/perl -CO\n",
              "# <your extra initialization here>\n",
              "use ", @use_class ? $use_class[0] : $tree_class, ";\n",
              "use strict;\n\n",
              "print qq(Content-Type: text/xml\\n\\n), ",
              "$tree_class->new->run('$self->{name}');\n";
    close $fh;

    chmod 0744, $filename;

}

sub _trim {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+\z//;
    return $str;
}


1;

__END__

=head1 NAME

RSS::Tree::Node - nodes in an C<RSS::Tree> tree

=head1 SYNOPSIS

    package MyNode;
    use base qw(RSS::Tree::Node);

=head1 DESCRIPTION

C<RSS::Tree::Node> objects represent the nodes in an C<RSS::Tree>
tree.  The root node of such a tree is given a list of items from an
RSS feed, and each node of the tree is a potential "output" for the
item.

=head1 CONSTRUCTOR

=over 4

=item RSS::Node->new([ $name [, $title ] ])

Create a new C<RSS::Node>.  C<$name> must consist entirely of one or
more Perl word-characters (alphanumerics plus underscore).

A node's name serves two purposes.  First, the program written for the
node by the tree's C<write_programs> method is named by appending
".pl" to the node's name.  Second, the tree's C<run> method takes the
name of one of the tree's nodes as an argument; only those RSS items
handled by the named node are passed through to the output.

A node's title becomes the title of the RSS feed it produces.

If missing or undefined, C<$title> defaults to C<$name>.  If C<$name>
is missing or undefined, the node has no name.  In that case, no
program will be written for it by the tree's C<write_programs> method,
and RSS items handled by the node simply disappear.  This is one way
to filter items from the feed.

=back

=head1 METHODS

=over 4

=item $node->name
=item $node->title

These methods return the node's name and title, respectively.

=item $node->add(@child)

Adds the elements of C<@child>, each of which should be a
C<RSS::Tree::Node> object, to the list of this node's child nodes.
Returns C<$node>.

=item $node->test($item)

Returns true if the given C<RSS::Tree::Item> satisfies this node's
test, meaning that the item will be handled by this node or one of its
descendants.

If either of this node's C<match_title> or C<match_author> methods
have previously been called, then this method returns true if the
item's title or author, respectively, matches the regular expression
provided to the most recently called of the two methods.  Otherwise,
it returns true by default.  Subclasses may override this method to
provide other kinds of testing.

=item $node->match_title($regex)
=item $node->match_author($regex)

See the description of the C<test> method for details.  These methods
both return C<$node>.

=item $node->handles($item [, $stop ])

Returns the node that will handle the given C<RSS::Tree::Item> item,
if that node is C<$node> or one of its descendants.

If C<$node-E<gt>test($item)> returns true, then the method will
recursively call the C<handles> method on its children (if any),
passing them the same arguments.  If any child returns a true value,
that value is returned from this method.  Otherwise, C<$node> is
returned.

If C<$node-E<gt>test($item)> does not return true, then one of two false
values is returned.  If C<$stop> is defined and is equal to the name
of C<$node>, then C<undef> is returned.  Otherwise, 0 is returned.
These distinct false values allow the caller to determine whether the
node named C<$stop> has been encountered; if so, no further searching
needs to be done.

=item $node->render($item)

Returns C<$item-E<gt>description>.  Subclasses may override this method to
provide other kinds of rendering.

=item $node->uri_for($item)

Returns the URI for the given item.  This method returns
C<$item-E<gt>link>, but certain RSS feeds may store the URI in a
different place.  A subclass may override this method to return the
correct URI.

=item $node->new_element(...)

This method is a convenience wrapper for the C<new_from_lol> method of
the C<HTML::Element> class, which is C<require>d when this method is
called.  The arguments to this method are wrapped in an array
reference, which is passed to C<new_from_lol>.  Example:

    my $elem = $self->new_element('p', 'This is ', [ 'i', 'italicized' ], ' text');

=item $node->find($context, $path [, @classes ])

This method is an alternate entry point for the enhanced node-finding
functionality offered by the C<RSS::Tree::HtmlDocument> class.  It
simply returns C<$context-E<gt>findnodes($path)> after replacing
C<"%s"> escape sequences in C<$path> by an XPath expression for the
classes in C<@classes>.  See C<RSS::Tree::HtmlDocument> for more
details.

=back
