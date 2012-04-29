# TODO: Delete old items from cache
# TODO: Perform node test before descending
# TODO: Limit number of items
# TODO: Somehow uncache feed/items orphaned by a changed URL

package RSS::Tree;

use Encode ();
use Errno;
use LWP::Simple qw($ua);
use RSS::Tree::Item;
use Try::Tiny ();
use XML::RSS;

use base qw(RSS::Tree::Node);
use strict;


$ua->agent("");


sub new {
    my ($class, $source, $url, $name, $title, @opts) = @_;
    my $self = $class->SUPER::new($name, $title, @opts);
    $self->{url}    = $url;
    $self->{source} = $source;
    return $self;
}

sub set_cache {
    my ($self, %opt) = @_;
    my $dir = $opt{dir};
    # TODO: die (?) if cache already set
    # TODO: die if name is undefined
    mkdir $dir or $!{EEXIST}
        or die "Failed to create cache directory $dir: $!\n";
    require DBM::Deep;
    my $cache = $self->{cache} = DBM::Deep->new("$dir/$self->{name}");
    $self->{feed_cache_seconds} = $opt{feed};
    $self->{item_cache_seconds} = $opt{items};
    return $self;
}

sub run {
    my ($self, $name) = @_;
    my $cache = $self->{cache};
    my $rss = XML::RSS->new->parse($self->_fetch_feed);
    my $items = $rss->{items};
    my $index = 0;
    my $title;

    while ($index < @$items) {
        my $item = $items->[$index];
        my $copy = { %$item };
        my $wrapper = RSS::Tree::Item->new($self, $copy);
        my $node = $self->process($wrapper, $name);
        if ($node && $node->name eq $name) {
            _set_content($item, $self->_get_content($node, $wrapper));
            $self->postprocess_item($item);
            ++$index;
            defined $title or $title = $node->Title;
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
    return RSS::Tree::HtmlDocument::Web->new($url);
}

sub write_programs {
    my ($self, %opt) = @_;
    my $prelude;

    if (exists $opt{prelude}) {
        $prelude = $opt{prelude};
    } elsif (exists $opt{prelude_file}) {
        open my $fh, '<', $opt{prelude_file}
            or die "Failed to open prelude file $opt{prelude_file}: $!\n";
        $prelude = do { local $/; <$fh> };
        close $fh;
    }

    $self->_write_program(ref $self, $prelude);

}

sub _get_content {
    my ($self, $node, $item) = @_;

    return $self->_cache(
        sub { _render($node, $item) },
        $self->{item_cache_seconds},
        'items', $item->link || $item->guid
    );

}

sub _download_feed {
    my $self = shift;
    defined(my $content = LWP::Simple::get($self->{source}))
        or die "Failed to download RSS feed from $self->{source}";
    return $content;
}

sub _fetch_feed {
    my $self = shift;
    return $self->_cache(
        sub { $self->_download_feed },
        $self->{feed_cache_seconds},
        'feed'
    );
}

sub _cache {
    my ($self, $generate, $duration, @keys) = @_;
    my $cache = $self->{cache};

    return $generate->() if !$cache || !defined $duration;

    # Different versions of DBM::Deep do this differently, apparently...
    if ($cache->can('lock_exclusive')) {
        $cache->lock_exclusive;
    } else {
        $cache->lock(DBM::Deep::LOCK_EX());
    }

    my $error;

    my $content = Try::Tiny::try {
        my $hash = $cache;
        $hash = $hash->{$_} ||= { } for @keys;
        my $timestamp = $hash->{timestamp};
        my $now       = time();
        my $content;

        if (!defined $timestamp || $now - $timestamp >= $duration) {
            $content           = $generate->();
            $hash->{content}   = Encode::encode_utf8($content);
            $hash->{timestamp} = $now;
        } else {
            $content = Encode::decode_utf8($hash->{content});
        }

        $content;

    } Try::Tiny::catch {
        $error = $_;
    } Try::Tiny::finally {
        $cache->unlock;
    };

    die $error if $error;

    return $content;

}

sub _render {
    my ($node, $item) = @_;
    my @repr = $node->render($item) or return;

    return join "", map {
        UNIVERSAL::isa($_, 'HTML::Element')
            ? do { $_->attr('id', undef); $_->as_HTML("", undef, { }) }
            : $_
    } @repr;

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
