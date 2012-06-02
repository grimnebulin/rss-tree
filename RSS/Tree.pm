package RSS::Tree;

use Errno;
use LWP::UserAgent;
use RSS::Tree::Cache;
use RSS::Tree::Item;
use XML::RSS;

use base qw(RSS::Tree::Node);
use strict;


my $DEFAULT_ITEM_CACHE_SECONDS = 60 * 60 * 24;

my $DEFAULT_FEED_CACHE_SECONDS = 60 * 5;


sub new {
    my ($class, %param) = @_;

    my $param = sub {
        my @value = map {
            exists $param{$_} ? $param{$_} : do { my $uc = uc; $class->$uc() }
        } @_;
        wantarray ? @value : $value[0];
    };

    my $self = $class->SUPER::new($param->('name', 'title'));

    $self->{feed} = $param->('feed');

    $self->{cache} = RSS::Tree::Cache->new(
        $self, $param->('cache_dir', 'feed_cache_seconds', 'item_cache_seconds')
    );

    $self->{agent_id}       = $param->('agent_id');
    $self->{keep_enclosure} = $param->('keep_enclosure');

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

sub AGENT_ID {
    return "";
}

sub KEEP_ENCLOSURE {
    return 1;
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
    my $index = 0;
    my $title;

    defined $name or $name = $self->name;

    while ($index < @$items) {
        my $item = $items->[$index];
        my $copy = { %$item };
        my $wrapper = RSS::Tree::Item->new($self, $copy);
        my $node = $self->process($wrapper, $name);
        if ($node && $node->name eq $name) {
            _set_content($item, $self->{cache}->cache_item($node, $wrapper));
            $self->postprocess_item($item);
            ++$index;
            defined $title or $title = $node->title;
        } else {
            splice @$items, $index, 1;
        }
    }

    $rss->{channel}{title} = $rss->{channel}{description} =
        defined $title ? $title : $name;

    # $rss->{channel}{link} = $self->{url} . $name . '.pl';

    return $rss->as_string;

}

sub download {
    my ($self, $url) = @_;
    require RSS::Tree::HtmlDocument::Web;
    return RSS::Tree::HtmlDocument::Web->new($url, $self);
}

sub postprocess_item {
    my ($self, $item) = @_;
    delete $item->{guid};
    delete $item->{enclosure} if !$self->{keep_enclosure};
}

sub write_programs {
    my ($self, %opt) = @_;
    $self->_write_program(ref $self, exists $opt{'use'} ? $opt{'use'} : ());
}

sub _agent {
    my $self = shift;
    return $self->{agent} ||= LWP::UserAgent->new(agent => $self->{agent_id});
}

sub _download {
    my ($self, $url) = @_;
    my $response = $self->_agent->get($url);
    return if !$response->is_success;
    return $response->decoded_content;
}

sub _download_feed {
    my $self = shift;
    defined $self->{feed}
        or die "No RSS feed defined for class ", ref $self, "\n";
    defined(my $content = $self->_download($self->{feed}))
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
    use base qw(RSS::Tree);

    use constant {
        FEED  => 'http://www.stuff.com/feed/rss.xml',
        NAME  => 'stuff',
        TITLE => 'Interesting Stuff'
    };

    # Split items whose titles match the regular expression /Movie:/
    # into a subfeed named "movies", and items whose titles match
    # /Television:/ into a subfeed named "tv".  Items falling into
    # neither of those categories will show up in the root item's
    # feed "stuff" (from the NAME constant above).

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
    # and extracting the div with id "body":

    sub render {
        my ($self, $item) = @_;
        return $item->page->findnodes('//div[@id="body"]')->shift;
    }

=head1 DESCRIPTION

An C<RSS::Tree> object forms the root of a tree of C<RSS::Tree::Node>
objects.  Each node in the tree (including the root node) represents a
subfeed into which some of the items from the root RSS feed will be
diverted.  Each node decides whether to accept items passed to it, and
also renders the items it does accept into HTML according to arbitrary
logic.  Facilities are provided to conveniently access the pages
linked to by RSS items, and to search both item text and web page text
using XPath.

Commonly, a tree will consist of only the root node, which can filter
out uninteresting items from the source feed and/or render the
interesting items arbitrarily.

Features are provided that should make it unnecessary to write a
constructor most (all?) of the time.

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

=item cache_dir

The directory where the cache file for this feed will be stored.  If
undefined, no cacheing will be performed.  It defaults to the value of
the C<RSS_TREE_CACHE_DIR> environment variable.

=item feed_cache_seconds

=item item_cache_seconds

The length of time that the feed text and item text will be cached,
respectively.  These paramters have no effect unless the C<cache_dir>
parameter is defined.  If C<feed_cache_seconds> is undefined, no feed
cacheing will be performed, and similarly for C<item_cache_seconds>.

C<feed_cache_seconds> defaults to 300 (five minutes), and
C<item_cache_seconds> defaults to 86400 (twenty-four hours).

=item agent_id

This is the User-Agent string that will be used by the
C<LWP::UserAgent> object that performs all web requests related to
this object.  It defaults to C<""> (the empty string).

=back

It is convenient not to have to write a constructor for every subclass
of C<RSS::Tree>, so each of the parameters described above can also be
supplied by a class method with the same name as the parameter, but
uppercased.  Explicitly:

=over 4

=item NAME
=item TITLE
=item FEED
=item CACHE_DIR
=item FEED_CACHE_SECONDS
=item ITEM_CACHE_SECONDS
=item AGENT_ID

=back

Such methods can be easily defined by the C<constant> pragma, e.g.:

    package MyTree;
    use base qw(RSS::Tree);
    use constant { FEED => 'http://...', NAME => 'foo', TITLE => 'FOO' };

=back

=head1 METHODS

=over 4

=item $tree->run($name)

Fetches the RSS feed associated with this root node, and distributes
each item to one of the nodes of the tree.  Returns a string
containing the original RSS document, from which all items EXCEPT
those claimed by the node named C<$name> have been removed.

=item $tree->download($url)

Returns an C<RSS::Tree::HtmlDocument::Web> object through which the
web page referenced by C<$url> can be accessed.

=item $tree->write_programs([ use => $module ])

Descends recursively through the tree.  For each node whose name is
defined, a file is written in the current directory whose name is
obtained by appending ".pl" to the name of the node.  The file
contains a short Perl program which emits the subset of the items in
the source feed that are matched by that particular node.

=back
