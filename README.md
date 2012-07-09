# SUMMARY

`RSS::Tree` is a Perl framework that allows one to divide a single
incoming RSS feed into a tree of outgoing RSS feeds, and/or apply
transformations to the feed's content at the same time.

# MOTIVATION

I subscribe to a large number of RSS feeds.  Many of them provide only
an incomplete representation of the content of the page they're linked
to.  Extra seconds spent waiting for the linked page to load really
add up when repeated across hundreds of articles per day, and some
articles turn out not to have been worth the wait.  I'd really prefer
to see as much article content as is convenient directly inside my
feed reader.

`RSS::Tree` is the result of my efforts to make reading my feeds more
efficient.  I've been using it happily for several months.  When I
subscribe to a new feed and discover that I'd like to filter or
transform it in some way, writing a new class to do the job often
takes less than a minute.

# EXAMPLES

This is a list of examples of the use of `RSS::Tree`, in approximately
increasing order of complexity.  All example code is assumed to reside
in a Perl module that begins with code similar to the following:

    package MyFeed;
    use base qw(RSS::Tree);
    use strict;
    use constant {
        NAME  => 'myfeed',
        TITLE => 'Source Feed',
        FEED  => 'http://xsourcefeed.com/rss/',
    };

## Filter Items

Suppose I'm only interested in feed items written by a particular
author.

    sub test {
        my ($self, $item) = @_;
        return $item->author =~ /Good Author/;
    }

Now I create the CGI program that serves up my new feed:

    $ perl -MMyFeed -e 'MyFeed->new->write_programs'

This command creates a program in the current directory called
`myfeed.pl`.  When invoked, that program downloads the source feed,
filters out items whose author is not "Good Author," and delivers the
rest.

## Transform Items

`RSS::Tree` provides a convenient way to manipulate an item's HTML
content, as well as that of the page it references, using XPath.

### Remove Ads

One of the feeds I read regularly incorporates annoyingly large banner
ads.  Examining the feed's content, I find that the ads are rendered
by an `<img>` HTML tag whose `src` attribute includes the string
`quadrupleclick`.  I want to remove any `<p>` elements from the item's
description that have such an image as a descendant.

    sub render {
        my ($self, $item) = @_;
        $_->detach for $item->content->find(
            '//p[descendant::img[contains(@src,"quadrupleclick")]]'
        );
        return $item->content;
    }

### Add Content

Another of my feeds is from a webcomic that often includes a secondary
joke in the `title` attribute of the strip's `<img>` element.  I'm too
lazy to hover my cursor over the image long enough to see the message;
I'd rather just show the message below the image, in italics.

    sub render {
        my ($self, $item) = @_;
        my ($image) = $item->description->find('//img');
        $image->postinsert(
            $self->new_element('p', [ 'i', $image->attr('title') ])
        ) if $image;
        return $item->description;
    }

### Incorporate Content From Linked Page

Many feeds provide brief snippets of the content of the page they're
linked to.  Others provide essentially no content at all; I need to
visit the linked page to see anything.  In either case, I'd rather
just read all of the content in my RSS reader.  `RSS::Tree` and XPath
make this easy.  I only need to examine the structure of the pages on
the site linked to by the items (Firebug is very helpful here), and
then formulate an appropriate XPath expression.

Many webcomics are easy to extract into a feed:

    sub render {
        my ($self, $item) = @_;
        return $item->page->find('//div[@id="comic"]/img');
    }

Textual content is just as easy:

    sub render {
        my ($self, $item) = @_;
        return $item->page->find('//div[%s]', 'body');
    }

For another feed, I want to pull in all `<p>` child elements of the
`<div>` element with a class of "entry", but only the elements that
have no attributes.

    sub render {
        my ($self, $item) = @_;
        return $item->page->find('//div[%s]/p[not(attribute::*)]', 'entry');
    }

A slightly more complicated example.  I want to include all content on
the linked page from the `<div class="article_body">` element, but
only the `<p>`, `<ul>`, `<ol>`, and `<blockquote>` children of that
element.

    sub render {
        my ($self, $item) = @_;
        return $item->page->find(
            '//div[%s]/*[self::p or self::ul or self::ol or self::blockquote]',
            'article_body'
        );
    }

An even more complicated example.  A certain feed I read includes only
brief snippets of the linked page.  Normally I would simply pull in
the page's content as described above, but some articles on this site
are very long, and some incorporate a large number of images or
embedded videos.  In such cases, I want to truncate the page content
at the page's "fold" (indicated by a `<div>` element with an `id` of
"more").  In either case, I first want to truncate the page content at
the div that has a class of "Tags".

    my $EMBED_LIMIT = 3;

    my $TEXT_LIMIT = 2000;

    sub render {
        my ($self, $item) = @_;
        my ($body) = $item->page->find('//div[%s]', 'Entry_Body') or return;

        $self->_truncate($body, 'child::div[%s]', 'Tags');
        $self->_truncate($body, '//div[@id="more"]') if _body_too_long($body);

        return $body;

    }

    sub _truncate {
        my ($self, $context, @xpath) = @_;
        for my $node ($self->find($context, @xpath)) {
            $node->parent->splice_content($node->pindex);
        }
    }

    sub _body_too_long {
        my $body = shift;
        return $body->findnodes('//img|//embed|//iframe')->size > $EMBED_LIMIT
            || length($body->as_trimmed_text) > $TEXT_LIMIT;
    }

## Split Items Into Separate Feeds

Suppose that the source feed mixes together many topics--various types
of popular media, say--that I would prefer to read in separate feeds.

    sub init {
        my $self = shift;
        $self->add(
            RSS::Tree::Node->new('tv', 'TV')->match_title('^TV:'),
            RSS::Tree::Node->new('movies', 'Movies')->match_title('^Film:'),
            RSS::Tree::Node->new('books', 'Books')->match_title('^Book:'),
        );
    }

Now I can create the CGI programs that serve up the various subfeeds
I've described:

    $ perl -MMyFeed -e 'MyFeed->new->write_programs'

This command creates programs `tv.pl`, `movies.pl`, `books.pl`, and
`myfeed.pl` in the current directory.  `tv.pl` shows only those items
from the source feed whose title matches the regular expression
`/^TV:/`; `movies.pl` and `books.pl` shows items whose titles match
`/^Film:/` and `/^Book:/`, respectively; and `myfeed.pl` shows items
meeting none of those criteria.

