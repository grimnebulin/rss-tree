package RSS::Tree;

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

use Errno;
use LWP::UserAgent;
use RSS::Tree::Cache;
use RSS::Tree::Item;
use XML::RSS;

use parent qw(RSS::Tree::Node);
use strict;


my $DEFAULT_ITEM_CACHE_SECONDS = 60 * 60 * 24;

my $DEFAULT_FEED_CACHE_SECONDS = 60 * 5;


sub new {
    my ($class, %param) = @_;

    my $param = sub {
        my @value = map {
            exists $param{$_} ? $param{$_} : do { my $uc = uc(); $class->$uc() }
        } @_;
        wantarray ? @value : $value[0];
    };

    my $self = $class->SUPER::new($param->('name', 'title'));

    $self->{$_} = $param->($_) for qw(feed limit agent_id keep_enclosure keep_guid);

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

sub KEEP_ENCLOSURE {
    return 1;
}

sub KEEP_GUID {
    return 0;
}

sub CACHE_DIR {
    return $ENV{RSS_TREE_CACHE_DIR};
}

sub ITEM_CACHE_SECONDS {
    return $DEFAULT_ITEM_CACHE_SECONDS;
}

sub FEED_CACHE_SECONDS {
    return $DEFAULT_FEED_CACHE_SECONDS;
}

sub run {
    my ($self, $name) = @_;
    my $rss   = XML::RSS->new->parse($self->{cache}->cache_feed);
    my $items = $rss->{items};
    my $limit = $self->{limit};
    my $index = 0;
    my $count = 0;
    my $title;

    defined $name  or $name  = $self->name;
    defined $limit or $limit = 9e99;

    while ($index < @$items) {
        splice(@$items, $index), last if ++$count > $limit;
        my $item    = $items->[$index];
        my $wrapper = RSS::Tree::Item->new($self, $item);
        my $node    = $self->handles($wrapper, $name);
        if ($node && $node->name eq $name) {
            $self->_postprocess_item($wrapper);
            _set_content($item, $self->{cache}->cache_item($node, $wrapper));
            ++$index;
            defined $title or $title = $node->title;
        } else {
            splice @$items, $index, 1;
        }
    }

    $rss->{channel}{title} = $rss->{channel}{description} =
        defined $title ? $title : $name;

    # return $rss->as_string;
    my $out = $rss->as_string;
    $out =~ s/^(.+encoding=)(['"])\2/$1$2UTF-8$2/;
    return $out;

}

sub download {
    my ($self, $url) = @_;
    my $response = $self->_agent->get($url);
    return if !$response->is_success;
    return $self->decode_response($response);
}

sub fetch {
    my ($self, $url) = @_;
    require RSS::Tree::HtmlDocument::Web;
    return RSS::Tree::HtmlDocument::Web->new($url, $self);
}

sub _postprocess_item {
    my ($self, $item) = @_;
    $self->postprocess_item($item);
    $item->set_guid(undef) if !$self->{keep_guid};
    delete $item->unwrap->{enclosure} if !$self->{keep_enclosure};
}

sub postprocess_item {
    # nop - can be overridden
}

sub write_programs {
    my ($self, %opt) = @_;

    my ($perl) = grep { -x } map { "$_/perl" } split /:/, $ENV{PATH}
        or die "No perl binary found in PATH\n";

    $self->_write_program(ref $self, $perl, exists $opt{'use'} ? $opt{'use'} : ());

}

sub _agent {
    my $self = shift;
    return $self->{agent} ||= LWP::UserAgent->new(
        defined $self->{agent_id} ? (agent => $self->{agent_id}) : (),
    );
}

sub decode_response {
    my ($self, $response) = @_;
    return $response->decoded_content;
}

sub _download_feed {
    my $self = shift;
    defined $self->{feed}
        or die "No RSS feed defined for class ", ref $self, "\n";
    defined(my $content = $self->download($self->{feed}))
        or die "Failed to download RSS feed from $self->{feed}\n";
    return $content;
}

sub _set_content {
    my ($item, $content) = @_;
    return if !defined $content;

    if (exists $item->{content} &&
        ref $item->{content} eq 'HASH' &&
        exists $item->{content}{encoded}) {
        $item->{content}{encoded} = $content;
    } else {
        $item->{description} = $content;
    }

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
undefined, no cacheing will be performed.  It defaults to the value of
the C<RSS_TREE_CACHE_DIR> environment variable.

Cacheing is handled by the C<DBM::Deep> module, which is C<require>d
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

=item agent_id

This is the User-Agent string that will be used by the
C<LWP::UserAgent> object that performs all web requests related to
this object.  It defaults to C<""> (the empty string).  If undefined,
no explicit user-agent will be set, and so the default agent supplied
by the C<LWP::UserAgent> module will be used.

=item keep_enclosure

If false, each RSS item processed by the object will be stripped of
its "enclosure" field.  Defaults to true.

=item keep_guid

If false, each RSS item processed by the object will be stripped of
its "guid" field.  Defaults to false.

=back

It is convenient not to have to write a constructor for every subclass
of C<RSS::Tree>, so each of the parameters described above can also be
supplied by a class method with the same name as the parameter, but
uppercased.  Explicitly:

=over 4

=item NAME
=item TITLE
=item FEED
=item LIMIT
=item CACHE_DIR
=item FEED_CACHE_SECONDS
=item ITEM_CACHE_SECONDS
=item AGENT_ID
=item KEEP_ENCLOSURE
=item KEEP_GUID

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

=item $tree->download($url)

Downloads the given URL.  Returns a string containing the content of
the URL, or C<undef> if the content could not be downloaded for any
reason.

Downloading is performed by an C<LWP::UserAgent> object that is
instantiated and cached when this method is first called.  An
exception will occur if the C<LWP::UserAgent> module is not
available.

=item $tree->decode_response($response)

This method should return the decoded content of C<$response>, an
C<HTTP::Response> object.  The default implementation simply returns
C<$response-E<gt>decoded_content()>, but a subclass may override this
method if special handling is needed.

=item $tree->fetch($url)

Returns an C<RSS::Tree::HtmlDocument::Web> object through which the
web page referenced by C<$url> can be accessed.

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
