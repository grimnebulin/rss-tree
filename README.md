# SUMMARY

`RSS::Tree` is a Perl framework that allows one to perform filters and
transformations on the contents of RSS feeds, as well as split a
single incoming feed into one or more outgoing feeds.


# MOTIVATION

I subscribe to a large number of RSS feeds.  Many of them provide only
an incomplete representation of the content of the page they're linked
to.  Extra seconds spent waiting for the linked page to load really
add up when repeated across hundreds of articles per day, and some
articles turn out not to have been worth the wait.  I'd really prefer
to see as much article content as is convenient directly inside my
feed reader.

`RSS::Tree` is the result of my efforts to make reading my feeds more
efficient.  When I subscribe to a new feed and discover that I'd like
to filter or transform it in some way, writing a new class to do the
job often takes less than a minute.

# EXAMPLES

This is a list of examples of the use of `RSS::Tree`.  All example
code is assumed to reside in a Perl module that begins with code
similar to the following:

    package MyFeed;
    use parent qw(RSS::Tree);
    use strict;
    use constant {
        NAME  => 'myfeed',
        TITLE => 'Source Feed',
        FEED  => 'http://xsourcefeed.com/rss/',
    };

The feed can be accessed by a simple Perl command:

    $ perl -MMyFeed -e 'print MyFeed->new->run'

## Transform Items

### Replace feed content with web content

Commonly, I want an alternate version of an existing feed where the
content is taken from the web pages linked to by the original feed's
items.  For example, I might examine the web site linked to by the
original feed using a tool like [Firebug](https://getfirebug.com/) and
discover that the main content of all pages is found in a &lt;div&gt;
element with id "main-content".  All I need to do is write a render
method for my class:

    sub render {
        my ($self, $item) = @_;
        return $item->page->find('//div[@id="main-content"]');
    }

Or perhaps the page content resides in a &lt;div&gt; element that
doesn't have a particular id, but has a class "articleBody".  That's
just as easy to grab:

    return $item->page->find('//div[%s]', 'articleBody');

The first argument to the find method is an augmented XPath
expression.  `%s` format specifiers are expanded into XPath predicates
that match the classes named by the remaining arguments.

### Modify items

Perhaps a feed supplies items that are fine on their own, but which
contain links to share the items on Facebook, Twitter, etc, which I'd
just as soon not see--they take up valuable vertical real estate.
Examining the feed source, I see that such links are found in a
top-level paragraph that has a class "share-links".  It's easy to
remove them:

    sub render {
        my ($self, $item) = @_;
        return $item->content->remove('p[%s]', 'share-links');
    }

Another feed has items with images that have humorous mouseover
captions, but I'm a keyboard-driven reader and don't want to have to
keep positioning my cursor over the images to read them.  The following
rendering routine appends a div containing the italicized mouseover
text to each image that has it:

    sub render {
        my ($self, $item) = @_;
        for my $img ($item->content->find('//img[@title]')) {
            $img->postinsert(
                $self->new_element('div', [ 'i', $img->attr('title') ])
            );
        }
    }

Yet another feed has items that are reviews of movies, TV shows, video
games, etc, and each links to a page that grades the object of the
review on a scale from A to F.  I'd rather see the grade in my feed
reader rather than having to click through.  Examining the page
source, I find that the grade, if it exists, is found in a
&lt;span&gt; element with the class "grade":

    sub render {
        my ($self, $item) = @_;
        my ($grade) = $item->page->find('//span[%s]', 'grade');
        return (
            $grade && $self->new_element('div', 'Grade: ', $grade->as_text),
            $self->render_default($item)
        );
    }

## Filter Items

Suppose I'm only interested in feed items written by a particular
author.

    sub test {
        my ($self, $item) = @_;
        return $item->author =~ /Good Author/;
    }

This will cause items from the source feed, other than those from Good
Author, to be discarded.

## Split Items Into Separate Feeds

Or perhaps rather than discard items not written by an author I like,
I'd rather split the source feed into two separate feeds: one with
items written by that author, and one for items written by anyone
else.  That way, if I fall too far behind in my reading, I can discard
the backlogged items in the "everyone else" feed without losing any
items from the author I like.

In this case, I need only override the `init` method to add a second
node to my tree:

    sub init {
        my $self = shift;
        $self->add(
            RSS::Tree::Node->new(
                'goodauthor', 'Good Author'
            )->match_author('Good Author')
        );
    }

Now, if I execute

    $ perl -MMyFeed -e 'MyFeed->new->run("goodauthor")'

...I'll see only the items from the author I like, and

    $ perl -MMyFeed -e 'MyFeed->new->run'

...will output the items from everyone else.

Here's a more complicated example that constructs a multilevel tree:

    sub init {
        my $self = shift;
        $self->add(
            RSS::Tree::Node->new('tv', 'TV')->match_title('^TV:')->add(
                RSS::Tree::Node->new('bb', 'Breaking Bad')
                               ->match_title('Breaking Bad'),
                RSS::Tree::Node->new('wire', 'The Wire')
                               ->match_title('The Wire'),
                RSS::Tree::Node->new->match_title('American Idol')
            ),
            RSS::Tree::Node->new('music', 'Music')->match_title('^Music:'),
            RSS::Tree::Node->new('film', 'Film')->match_title('^Film:')
        );
    }

(The "American Idol" node is anonymous--no name was passed to its
constructor--so items handled by it are simply discarded.)

If I were to define a `render` method on the main tree class, it would
be inherited by all of the nodes in the tree.  I would need to define
a subclass of `RSS::Tree::Node` if I wanted different nodes in the
tree to render themselves in a different way, or for more complicated
matching than simple regex matching against items' creator, title,
author, etc.

# MISCELLANEOUS CONSIDERATIONS

## Cacheing

It is highly recommended to employ cacheing, especially for feeds
which render items by accessing the associated web pages.  Setting the
environment variable `RSS_TREE_CACHE_DIR` will cause feeds to be
cached in the directory named there, both the original source feed (by
default, for five minutes) and the individual feed items, as rendered
by the user code (by default, for one day).

The `DBM::Deep` module is employed to store cached information to
disk.

## Accessing Feeds

The transformed feeds output by `RSS::Tree` are conveniently accessed
by aggregator services as simple, old-fashioned CGI programs.  The
`write_programs` method of `RSS::Tree` can create these programs.  For
example, consider the above multilevel tree example.  The following
command:

    $ perl -MMyFeed -e 'MyFeed->new->write_programs'

...would create executable files `tv.pl`, `bb.pl`, `wire.pl`,
`music.pl`, `film.pl`, and `myfeed.pl` in the current directory.  Each
program, when executed, would access the (possibly cached) source feed
and emit a feed containing only those items handled by the
corresponding node.

Stored in a web server directory set up to allow execution of CGI
programs, these programs then become *bona fide* RSS feeds, to which
aggregator services can be directed.
