# TODO: Delete old items from cache
# TODO: Perform node test before descending
# TODO: Limit number of items
# TODO: Somehow uncache feed/items orphaned by a changed URL

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

    $self->{agent_id} = $param->('agent_id');

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
