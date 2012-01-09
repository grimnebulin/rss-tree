package RSS::Tree;

use Errno;
use RSS::Tree::Item;
use RSS::Tree::Node;
use Try::Tiny ();
use XML::RSS;
use strict;

our @ISA = qw(RSS::Tree::Node);

sub new {
    my ($class, $source, $name, $title, @opts) = @_;
    my $self = $class->SUPER::new($name, $title, @opts);
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
    $self->{cache} = DBM::Deep->new("$dir/$self->{name}");
    $self->{feed_cache_seconds} = $opt{feed};
    $self->{item_cache_seconds} = $opt{items};
    return $self;
}

sub run {
    my ($self, $name) = @_;
    my $cache = $self->{cache};
    my $rss   = XML::RSS->new->parse($self->_fetch_feed);
    my $items = $rss->{items};
    my $index = 0;
    my $title;

    while ($index < @$items) {
        my $item = $items->[$index];
        my $copy = { %$item };
        my $wrapper = RSS::Tree::Item->new($copy);
        my $node = $self->process($wrapper, $name);
        if ($node && $node->name eq $name) {
            $item->{description} = $self->_get_description($node, $wrapper);
            ++$index;
            defined $title or $title = $node->Title;
        } else {
            splice @$items, $index, 1;
        }
    }

    $rss->{channel}{title} = $rss->{channel}{description} =
        defined $title ? $title : $name;

    return $rss->as_string;

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

sub _get_description {
    my ($self, $node, $item) = @_;
    return $self->_cache(
        $self->{item_cache_seconds},
        sub { $node->render($item) },
        'items', $item->link
    );
}

sub _download_feed {
    my $self = shift;
    require LWP::Simple;
    defined(my $content = LWP::Simple::get($self->{source}))
        or die "Failed to download RSS feed from $self->{source}";
    return $content;
}

sub _fetch_feed {
    my $self = shift;
    return $self->_cache(
        $self->{feed_cache_seconds},
        sub { $self->_download_feed },
        'feed'
    );
}

sub _cache {
    my ($self, $duration, $generate, @keys) = @_;
    my $cache = $self->{cache};

    return $generate->() if !$cache || !defined $duration;

    $cache->lock_exclusive;
    my $content;

    Try::Tiny::try {
        my $hash = $cache;
        $hash = $hash->{$_} ||= { } for @keys;
        my $timestamp = $hash->{timestamp};
        my $now = time();

        if (!defined $timestamp || $now - $timestamp >= $duration) {
            $hash->{content}   = $generate->();
            $hash->{timestamp} = $now;
        }

        $content = $hash->{content};

    } Try::Tiny::finally {
        $cache->unlock;
    };

    return $content;

}


1;
