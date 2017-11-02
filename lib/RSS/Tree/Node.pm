package RSS::Tree::Node;

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

use Carp ();
use RSS::Tree::HtmlDocument;
use Scalar::Util;
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

sub clear {
    my $self = shift;
    @{ $self->{children} } = ();
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

sub match_category {
    my ($self, $regex) = @_;
    $self->{test} = sub {
        return 0 < grep { _trim($_) =~ /$regex/i } $_[0]->categories
    };
    return $self;
}

sub _match {
    my ($self, $field, $regex) = @_;
    $field =~ /^[^\W\d]\w*\z/ or die qq(Invalid field "$field"\n);
    $self->{test} = sub { _trim($_[0]->$field()) =~ /$regex/i };
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
    return $self->parent
        ? $self->parent->render($item)
        : $self->render_default($item);
}

sub render_default {
    my ($self, $item) = @_;
    return $item->content;
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

sub new_page {
    my ($self, $uri, $content) = @_;
    return RSS::Tree::HtmlDocument->new($uri, $content);
}

sub find {
    my ($self, $context, $path, @classes) = @_;
    return RSS::Tree::HtmlDocument::_find_all($context, $path, @classes)
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

sub wrap {
    my ($self, $wrappee, $wrapper) = @_;
    $wrapper = $self->new_element($wrapper) if !ref $wrapper;
    $wrappee->preinsert($wrapper);
    $wrapper->push_content($wrappee);
    return $wrapper;
}

sub clean_element {
    my ($self, $elem) = @_;

    if ($elem->tag eq 'script') {
        $elem->detach;
    } else {
        $elem->attr($_, undef) for grep m{
            ^ (?: data- | item | on | (?: id | class ) \z )
        }x, $elem->all_attr_names;

        $self->clean_element($_) for grep ref, $elem->content_list;
    }

    return $self;

}

sub _children {
    return @{ shift->{children} };
}

sub _write_program {
    my ($self, $tree_class, $perl, %options) = @_;

    $_->_write_program($tree_class, $perl, %options) for $self->_children;

    return if !defined $self->{name};

    require File::Spec;

    my $path = File::Spec->catfile($options{dir} // '.', "$self->{name}.pl");

    open my $fh, '>', $path
        or die "Can't open file $path for writing: $!\n";

    my $params;

    if (defined(my $init = $options{init})) {
        ref $options{init} eq 'HASH' or die "init parameter must be a hash";
        $params = substr _dump($options{init}), 1, -1;
    } else {
        $params = "";
    }

    my $name = _dump($self->{name});

    print $fh "#!$perl -CO\n",
              "use ", $options{use} // $tree_class, ";\n",
              "use strict;\n\n",
              "print qq(Content-Type: text/xml\\n\\n), ",
              "$tree_class->new($params)->run($name);\n";

    close $fh;

    chmod $options{mode} // 0744, $path;

}

sub _dump {
    require Data::Dumper;
    return Data::Dumper->new([ shift ])->Terse(1)->Indent(0)->Quotekeys(0)->Dump;
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
    use parent qw(RSS::Tree::Node);

=head1 DESCRIPTION

C<RSS::Tree::Node> objects represent the nodes in an C<RSS::Tree>
tree.  The root node of such a tree is given a list of items from an
RSS feed, and each node of the tree is a potential "output" for the
item.

=head1 CONSTRUCTOR

=over 4

=item RSS::Tree::Node->new([ $name [, $title ] ])

Create a new C<RSS::Node>.  C<$name> must consist entirely of one or
more Perl word-characters (alphanumerics plus underscore), or an
exception will be thrown.

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

These accessors return the node's name and title, respectively.

=item $node->parent

This accessor returns the node's parent if it has one, of C<undef>
otherwise.

=item $node->root

Returns the root node of the tree of which C<$node> is a part.

=item $node->add(@child)

Adds the elements of C<@child>, each of which should be a
C<RSS::Tree::Node> object, to the list of this node's child nodes.
The parent of node is set to C<$node>.  Returns C<$node>.

=item $node->clear

Removes all child elements and returns C<$node>.

=item $node->test($item)

Returns true if the given C<RSS::Tree::Item> satisfies this node's
test, meaning that the item will be handled by this node or one of its
descendants.

The default implementation returns true, unless one of the
C<match_title>, C<match_author>, or C<match_creator> methods have been
called.  In that case, it returns true if the item's title, author, or
creator, respectively, match the regular expression that was passed to
that method.  Those attributes of the item are trimmed of leading and
trailing whitespace before being tested by the regex.  If more than
one of the aforementioned methods have been called, the last such
method determines the behavior of the C<test> method.

This default behavior is a convenience for the common case of testing
an item's title, author, or creator.  For other kinds of tests, a
subclass of C<RSS::Tree::Node> must be created that overrides the
C<test> method.

=item $node->match_title($regex)
=item $node->match_author($regex)
=item $node->match_creator($regex)

See the description of the C<test> method for details.  These methods
all return C<$node>.

=item $node->handles($item [, $stop ])

Returns the node that will handle the given C<RSS::Tree::Item> item,
if that node is C<$node> or one of its descendants.

If C<$node-E<gt>test($item)> returns true, then the method will
recursively call the C<handles> method on its children (if any), in
the order they were added, passing them the same C<$item> and C<$stop>
arguments.  If any child node returns a true value, that value (which
will be the node that handles C<$item>) is returned from this method.
Otherwise, C<$node> is returned.

If C<$node-E<gt>test($item)> does not return true, then one of two
false values is returned.  If C<$stop> is defined and is equal to the
name of C<$node>, then C<undef> is returned.  Otherwise, C<0> is
returned.  These distinct false values allow the caller to determine
whether the node named C<$stop> has been encountered; if so, no
further searching needs to be done.

=item $node->render($item)

Renders the given RSS item C<$item> into a desired textual
representation.  The method will be called in list context.
C<HTML::Element> objects in the return list are stringified by calling
that class's C<as_HTML> method; all other objects are stringified in
the default manner (eg, by being used in a string context).  The
stringified elements of the returned list are concatenated together,
and the resulting string is taken to be the rendered form of C<$item>.

The default implementation operates as follows: If C<$node> has a
parent C<$parent> (that is, it is not the root of the tree in which it
resides), then C<$parent-E<gt>render($item)> is returned.  Otherwise,
C<$node->render_default($item)> is returned.

Typically, the C<RSS::Tree> object at the root of the tree would
override this method to perform appropriate rendering, which will then
be inherited by the entire tree.

=item $node->render_default($item)

This method provides a sensible default way to render RSS items.  It
returns the item's content (that is, C<$item-E<gt>content>) if is has
any, otherwise it returns the item's description (that is,
C<$item-E<gt>description>).

=item $node->uri_for($item)

Returns the URI for the given item.  This method returns
C<$item-E<gt>link>, but certain oddball RSS feeds may store the URI in
a different place (such as the C<guid> field).  A subclass may
override this method to return the correct URI.

=back

=head1 UTILITY METHODS

=over 4

=item $node->new_element(...)

This method is a convenience wrapper for the C<new_from_lol>
constructor of the C<HTML::Element> class.  The arguments to this
method are wrapped in an array reference, which is passed to
C<new_from_lol>.  Example:

    my $elem = $self->new_element('p', 'This is ', [ 'i', 'italicized' ], ' text');

=item $node->new_page($uri, $content)

This method simply constructs and returns an
C<RSS::Tree::HtmlDocument> object, passing C<$uri> and C<$content> to
its constructor.  See that class for details.

=item $node->find($context, $path [, @classes ])

This method is an alternate entry point for the enhanced node-finding
functionality offered by the C<RSS::Tree::HtmlDocument> class.  It
simply returns C<$context-E<gt>findnodes($path)> after replacing
C<"%s"> escape sequences in C<$path> by an XPath expression for the
classes in C<@classes>.  See C<RSS::Tree::HtmlDocument> for more
details.

Conceivably a future version of C<RSS::Tree> might permit alternate
means of finding nodes other than XPath.

=item $node->remove($context, $path [, @classes ]);

This method is an alternate entry point for the node-removing
functionality of the C<RSS::Tree::HtmlDocument> class.  In short, the
nodes returned by C<$node-E<gt>find($context, $path, @classes)> are
removed from the document to which they belong.

=item $node->truncate($context, $path [, @classes ]);

This method is an alternate entry point for the node-truncating
functionality of the C<RSS::Tree::HtmlDocument> class.  In short, the
nodes returned by C<$node-E<gt>find($context, $path, @classes)>, along
with the following sibling elements of each, are removed from the
document to which they belong.

=item $node->wrap($wrappee, $wrapper)

The element C<$wrappee> is appended to the element C<$wrapper>, which
then takes the place of C<$wrappee> in the document to which
C<$wrappee> belongs.  C<$wrapper> is returned.

If C<$wrapper> is not a reference, it is first transformed into an
empty C<HTML::Element> object with C<$wrapper> as its tag name.  That
allows one to write, for example:

    my $div = $node->wrap($element, 'div');

=item $node->clean_element($element)

This method "cleans" the C<HTML::Element> object C<$element> by
removing from the HTML tree rooted at it certain "elements" (broadly
speaking) which are unlikely to be meaningful outside of the element's
original context.  Specifically:

=over 4

=item *

All C<E<lt>scriptE<gt>> elements in the tree are detached from their
parents.

=item *

Certain attributes are removed from all other elements in the tree:

=over 4

=item *

id

=item *

class

=item *

All custom data attributes; that is, those attributes whose names
start with "data-".

=item *

All attributes whose names start with "item", such as those in the
HTML5 microdata specification ("itemscope", "itemtype", etc).

=item *

All attributes whose names start with "on", such as those which define
event handlers ("onclick", "onmouseover", etc).

=back

=back

Returns C<$node>.

=back
