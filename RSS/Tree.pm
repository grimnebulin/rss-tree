package RSS::Tree;

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

use Errno;
use HTTP::Headers;
use RSS::Tree::Cache;
use RSS::Tree::HtmlDocument;
use RSS::Tree::Item;
use Scalar::Util;
use XML::Feed;

use parent qw(RSS::Tree::Node);
use strict;


my $DEFAULT_ITEM_CACHE_SECONDS = 60 * 60 * 24;

my $DEFAULT_FEED_CACHE_SECONDS = 60 * 5;

my %AUTORESOLVE = (
    img    => [ 'src'  ],
    iframe => [ 'src'  ],
    embed  => [ 'src'  ],
    a      => [ 'href' ],
);


sub new {
    my ($class, %param) = @_;

    my $param = sub {
        my @value = map {
            exists $param{$_} ? $param{$_} : do { my $uc = uc(); $class->$uc() }
        } @_;
        wantarray ? @value : $value[0];
    };

    my $self = $class->SUPER::new($param->('name', 'title'));

    $self->{$_} = $param->($_) for qw(
        feed limit keep_enclosure keep_guid autoclean autoresolve
    );

    if (exists $param{agent}) {
        $self->{agent} = $param{agent};
    } else {
        my $config = $param->('agent_config');
        my $id     = $param->('agent_id');
        $self->{agent_config} = {
            defined $id ? (agent => $id) : (),
            defined $config ? %$config : (),
        };
    }

    $self->{cache} = RSS::Tree::Cache->new(
        $self, $param->('cache_dir', 'feed_cache_seconds', 'item_cache_seconds')
    );

    $self->init;

    return $self;

}

sub init {
    # No-op.  Subclasses may override this to initialize themselves.
}

sub NAME {
    undef;
}

sub TITLE {
    undef;
}

sub FEED {
    undef;
}

sub LIMIT {
    undef;
}

sub AGENT_ID {
    return "";
}

sub AGENT_CONFIG {
    return undef;
}

sub KEEP_ENCLOSURE {
    return 1;
}

sub KEEP_GUID {
    return 0;
}

sub AUTOCLEAN {
    return 1;
}

sub AUTORESOLVE {
    return 1;
}

sub CACHE_DIR {
    undef;
}

sub ITEM_CACHE_SECONDS {
    return $DEFAULT_ITEM_CACHE_SECONDS;
}

sub FEED_CACHE_SECONDS {
    return $DEFAULT_FEED_CACHE_SECONDS;
}

my @FEED_FIELDS = qw(
    title base link description author language copyright modified
    generator self_link first_link last_link next_link previous_link
    current_link next_archive_link prev_archive_link
);

sub _empty_copy_of {
    my $feed = shift;
    my ($format, @version) = split / /, $feed->format;
    my $copy = XML::Feed->new($format, @version ? (version => $version[0]) : ());
    for my $field (@FEED_FIELDS) {
        my $value = $feed->$field;
        $copy->$field($value) if defined $value;
    }
    return $copy;
}

sub run {
    my ($self, $name) = @_;
    my $cache   = $self->{cache};
    # my $infeed  = XML::Feed->parse($cache->cache_feed);
    my $f = $cache->cache_feed;
    my $infeed  = XML::Feed->parse(\$f);
    my $outfeed = _empty_copy_of($infeed);
    my @items   = $infeed->items;
    my $limit   = $self->{limit};
    my $index   = 0;
    my $count   = 0;
    my $title;

    defined $name  or $name  = $self->name;
    defined $limit or $limit = 9e99;

    while ($index < @items) {
        last if ++$count > $limit;
        my $item    = $items[$index];
        my $wrapper = RSS::Tree::Item->new($self, $item);
        my $node    = $self->handles($wrapper, $name);
        if ($node && defined $node->name && $node->name eq $name) {
            $self->_postprocess_item($wrapper);
            _set_content(
                $item, $cache->cache_item(
                    $wrapper, sub { $self->_render($node, @_) }
                ),
            );
            ++$index;
            defined $title or $title = $node->title;
            $outfeed->add_entry($item);
        }
    }

    $title = defined $title ? $title : $name;
    $outfeed->title($title);
    $outfeed->description($title);

    # return $rss->as_string;
    # The as_xml method sometimes returns an <?xml?> document with an
    # empty encoding attribute, which breaks some readers.
    # This is a hack to work around that.
    # (Is this still needed after moving to XML::Feed?)
    my $out = $outfeed->as_xml;
    $out =~ s/^(.+encoding=)(['"])\2/$1$2UTF-8$2/;
    return $out;

}

sub _render {
    my ($self, $node, $item) = @_;
    my @content = $node->render($item);
    @content > 0 or @content = $node->render_default($item);
    @content = $self->_clean_output(@content)
        if $self->{autoclean};
    @content = $self->_resolve_output($item, @content)
        if $self->{autoresolve};
    return RSS::Tree::HtmlDocument::_render(@content);
}

sub _clean_output {
    my $self = shift;
    return grep {
        !RSS::Tree::HtmlDocument::_is_html_element($_) || (
            $self->clean_element($_), $_->tag ne 'script'
        )
    } @_;
}

sub _resolve_output {
    my ($self, $item, @elems) = @_;
    my $follow = $self->{autoresolve} eq 'follow';
    for my $elem (@elems) {
        $elem = $self->_resolve_element($item, $elem->clone, $follow)
            if RSS::Tree::HtmlDocument::_is_html_element($elem);
    }
    return @elems;
}

sub _resolve_element {
    my ($self, $item, $elem, $follow) = @_;

    if (my $attrs = $AUTORESOLVE{ $elem->tag }) {
        for my $attr (@$attrs) {
            if (defined(my $value = $elem->attr($attr))) {
                $elem->attr($attr, $item->uri($value, $follow));
            }
        }
    }

    $self->_resolve_element($item, $_, $follow)
        for grep ref, $elem->content_list;

    return $elem;

}

sub _postprocess_item {
    my ($self, $item) = @_;
    $self->postprocess_item($item);
    # $item->set_guid(undef) if !$self->{keep_guid};
    # delete $item->unwrap->{enclosure} if !$self->{keep_enclosure};
}

sub postprocess_item {
    # nop - can be overridden
}

sub write_programs {
    my ($self, %opt) = @_;
    my $perl;

    require File::Spec;

    for my $bin (map  { File::Spec->catfile($_, 'perl') }
                 grep { File::Spec->file_name_is_absolute($_) }
                 split /:/, $ENV{PATH}) {
        $perl = $bin, last if -x $bin;
    }

    defined $perl or die "No appropriate perl binary found in PATH\n";

    $self->_write_program(ref $self, $perl, exists $opt{'use'} ? $opt{'use'} : ());

}

sub agent {
    my $self = shift;
    return $self->{agent} ||= do {
        require LWP::UserAgent;
        LWP::UserAgent->new(%{ $self->{agent_config} });
    };
}

sub decode_response {
    my ($self, $response) = @_;
    return $response->decoded_content;
}

sub _download_item {
    my ($self, $uri) = @_;
    my $response = $self->agent->get($uri);
    return if !$response->is_success;
    return $self->decode_response($response, $uri);
}

sub _download_feed {
    my $self = shift;
    defined $self->{feed}
        or die "No RSS feed defined for class ", ref $self, "\n";
    my $response = $self->agent->get($self->{feed});
    if (!$response->is_success) {
        my $err = $response->header('Client-Warning') eq 'Internal response'
               && $response->decoded_content;
        die "Failed to download RSS feed from $self->{feed}",
            defined $err ? (': ', $err) : (), "\n";
    }
    return $response->decoded_content;
}

sub _set_content {
    my ($item, $content) = @_;
    return if !defined $content;
    $item->content(XML::Feed::Content->new({ body => $content }));
}


1;

__END__

=head1 NAME

RSS::Tree - a tree of nodes for filtering and transforming RSS items

=head1 SYNOPSIS

    package MyTree;
    use parent qw(RSS::Tree);

    use constant {
        NAME  => 'stuff',
        TITLE => 'Interesting Stuff'
        FEED  => 'http://www.stuff.com/feed/rss.xml',
    };

    # Split items whose titles match the regular expression /Movie:/
    # into a subfeed named "movies", and items whose titles match
    # /Television:/ into a subfeed named "tv".  Items falling into
    # neither of those categories will show up in the root item's
    # feed named "stuff".

    sub init {
        my $self = shift;
        $self->add(
            RSS::Tree::Node->new('movies', 'Interesting Movies')
                           ->match_title('Movie:'),
            RSS::Tree::Node->new('tv',     'Interesting TV Shows')
                           ->match_title('Television:'),
        );
    }

    # Ignore items with Boring Guy as the author:

    sub test {
        my ($self, $item) = @_;
        return $item->author !~ /Boring Guy/;
    }

    # Render the item by going to the page it links to
    # and extracting the div with id "main-content":

    sub render {
        my ($self, $item) = @_;
        return $item->page->find('//div[@id="main-content"]');
    }

=head1 DESCRIPTION

An C<RSS::Tree> object forms the root of a tree of C<RSS::Tree::Node>
objects.  (C<RSS::Tree> is itself a subclass of C<RSS::Tree::Node>.)
Each node in the tree (including the root node) represents a subfeed
into which some of the items from the root RSS feed may be diverted.
Each node decides whether to handle items passed to it, and also
renders the items it does handle into HTML.  Facilities are provided
to conveniently access the pages linked to by RSS items, and to search
both item text and web page text using XPath.

Commonly, a tree will consist of only the single root node, which can
filter out uninteresting items from the source feed and/or render the
interesting items in arbitrary ways.

Features are provided that should make it unnecessary to write a
constructor most of the time.

=head1 CONSTRUCTOR

=over 4

=item new(%param)

Creates a new C<RSS::Tree> object.  C<%param> is a hash of parameters,
of which the following are recognized:

=over 4

=item name
=item title

These are the root node's name and title.  They are passed to the
superclass C<RSS::Tree::Node> constructor, which see.

=item feed

The URL for the source RSS feed.  It is not an error for it to be
undefined, but if it is, an exception will be raised if the C<run>
method is ever called.

=item limit

The maximum number of items that will be taken from the source RSS
feed.  If undefined, which is the default, all items will be taken.
This parameter might be useful for feeds which retain a large number
of items, more than one wishes to incur the cost of rendering
repeatedly.

=item cache_dir

The directory where the cache file for this feed will be stored.  If
undefined (the default), no caching will be performed.

Caching is handled by the C<DBM::Deep> module, which is C<require>d
when any item is to be cached.  An exception will occur if that module
is not available.

=item feed_cache_seconds
=item item_cache_seconds

The length of time in seconds that the feed text and item text will be
cached, respectively.  These parameters have no effect unless the
C<cache_dir> parameter is defined.  If C<feed_cache_seconds> is
undefined, no feed cacheing will be performed, and similarly for
C<item_cache_seconds>.

C<feed_cache_seconds> defaults to 300 (five minutes), and
C<item_cache_seconds> defaults to 86400 (twenty-four hours).

=item agent

This is a user-agent object which will be used to dispatch requests to
the archive referred to by the new object; it should be an instance of
the C<LWP::UserAgent> class.

If this parameter is not present, an C<LPW::UserAgent> object will be
constructed when needed.  This object can be configured by the
parameters C<agent_config> and C<agent_id>, below.

=item agent_config

If defined, this parameter should be a hash of parameters that will be
passed to the C<LWP::UserAgent> constructor when an object of that
type is needed.  It is ignored if the C<agent> parameter is present.

The default value is C<undef>.

If the only parameter to be set is C<agent> (which sets the object's
user-agent), the C<agent_id> parameter provides a slightly more
convenient way to set it.

=item agent_id

This parameter specifies the user-agent that will be passed to the
C<LWP::UserAgent> constructor when an object of that type is needed.
It is ignored if the C<agent> parameter is present, or if an C<agent>
key is present in the C<agent_config> parameter.

The default value is C<""> (the empty string).  If undefined, no
explicit user-agent will be set, and so the default agent supplied by
the C<LWP::UserAgent> module will be used.

=item keep_enclosure

If false, each RSS item processed by the object will be stripped of
its "enclosure" field.  Defaults to true.

=item keep_guid

If false, each RSS item processed by the object will be stripped of
its "guid" field.  Defaults to false.

=item autoclean

A boolean flag.  If true, then all C<HTML::Element> objects returned
by the C<render> method of all nodes in this tree will be cleaned by
calling the C<RSS::Tree::Node> method C<clean_element> on them prior
to stringifying the objects into the destination RSS feed.  Defaults
to true.

In addition, C<E<lt>scriptE<gt>> elements returned by the C<render>
method of all nodes in this tree are omitted entirely from the
stringified RSS output.

See the C<RSS::Tree::Node> class for details on the C<clean_element>
method.

=item autoresolve

If this parameter is true, then all C<HTML::Element> objects returned
by the C<render> method of all nodes in this tree will be
"autoresolved"; that is, certain attributes of each such element, as
well as those of all of their descendent elements, will be converted
from relative URIs to absolute URIs, using the URI of the source RSS
item as a base.  Attributes which will so converted include:

=over 4

=item *

The C<E<lt>srcE<gt>> attribute of C<E<lt>imgE<gt>>,
C<E<lt>iframeE<gt>>, and C<E<lt>embedE<gt>> elements.

=item *

The C<E<lt>hrefE<gt>> attribute of C<E<lt>aE<gt>> elements.

=back

If the value of this parameter is equal to the string "follow", then
the base URI is obtained by issuing an HTTP HEAD request for the
associated item's URI, and using the base URI of the final request,
after any redirections have occurred.  This may be necessary if a
feed's items link to a proxy service.

If both of the C<autoclean> and C<autoresolve> parameters are true,
then autocleaning happens before autoresolving.

The default value is C<1>.

=back

It is convenient not to have to write a constructor for every subclass
of C<RSS::Tree>, so most of the parameters described above can also be
supplied by a class method with the same name as the parameter, but
uppercased.  Specifically:

=over 4

=item NAME

=item TITLE

=item FEED

=item LIMIT

=item CACHE_DIR

=item FEED_CACHE_SECONDS

=item ITEM_CACHE_SECONDS

=item AGENT_ID

=item AGENT_CONFIG

=item KEEP_ENCLOSURE

=item KEEP_GUID

=item AUTOCLEAN

=item AUTORESOLVE

=back

Such methods can be easily defined by the C<constant> pragma, e.g.:

    package MyTree;
    use parent qw(RSS::Tree);
    use constant { FEED => 'http://...', NAME => 'foo', TITLE => 'Foo' };

A parameter passed to the constructor overrides the parameter value
returned by these methods.

=back

=head1 METHODS

=over 4

=item $tree->init

This method is called by the constructor immediately before it
returns.  The default implementation does nothing, but subclasses may
override it to perform additional initialization, such as adding child
nodes.

=item $tree->agent

Returns the C<LWP::UserAgent> object used by this object, creating it
if it does not already exist.

=item $tree->run([ $name ])

Fetches the RSS feed associated with this root node, and returns a
string containing the original RSS document, from which all items
EXCEPT those handled by the node named C<$name> have been removed.  If
C<$name> is omitted, it defaults to C<$tree-E<gt>name>.

For example, consider a tree with a root node C<$root> named "foo" and
child nodes named "bar" and "baz":

                     _____
                    | foo |
                     -----
                    /     \
                   /       \
             _____          _____
            | bar |        | baz |
             -----          -----

Then C<$root-E<gt>run('bar')> returns the source RSS feed from which
all items except those handled by the "bar" node have been removed;
C<$root-E<gt>run('baz')> returns the feed from which all items except
those handled by the "baz" node have been removed; and
C<$root-E<gt>run('foo')> and C<$root-E<gt>run()> return all items
except those handled by the "foo" node.

=item $tree->decode_response($response, $uri)

This method should return the decoded content of C<$response>, an
C<HTTP::Response> object which was returned by an HTTP GET request to
C<$uri>, the link to one of the items handled by this tree.

The default implementation simply returns
C<$response-E<gt>decoded_content()>, but a subclass may override this
method if special handling is needed.

The C<$uri> argument probably isn't normally useful, but is provided
in case the source feed has links to multiple different web sites, and
special handling is needed only for some of them.

=item $tree->postprocess_item($item)

This method does nothing, but a subclass may override it to perform
any desired postprocessing on C<$item> before it is rendered.

=item $tree->write_programs([ use => $module ])

Descends recursively through the tree.  For each node in the tree
whose name is defined, a file is written in the current directory
whose name is obtained by appending ".pl" to the name of the node.
The file contains a short Perl program which emits the subset of the
items in the source feed that are matched by that particular node.

If the C<$module> parameter is supplied, each generated Perl program
will C<use> that module rather than the module to which C<$tree>
belongs.  This is part of an experimental feature that has yet to be
developed fully.

=back
