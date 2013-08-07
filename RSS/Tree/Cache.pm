package RSS::Tree::Cache;

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

use Encode ();
use Errno;
use Scalar::Util;
use Try::Tiny ();
use RSS::Tree::HtmlDocument;
use strict;


sub new {
    my ($class, $parent, $dir, $feed_seconds, $item_seconds) = @_;

    $dir = do { require Cwd; Cwd::abs_path($dir) } if defined $dir;

    my $self = bless {
        file         => $parent->name,
        dir          => $dir,
        feed_seconds => $feed_seconds,
        item_seconds => $item_seconds,
    }, $class;

    Scalar::Util::weaken($self->{parent} = $parent);

    return $self;

}

sub _dbm {
    my $self = shift;
    return exists $self->{dbm}
        ? $self->{dbm}
        : ($self->{dbm} = $self->_make_dbm);
}

sub _make_dbm {
    my $self = shift;

    defined $self->{dir} or return;

    require DBM::Deep;

    mkdir $self->{dir}
        or $!{EEXIST}
        or die "Failed to create RSS cache directory $self->{dir}: $!\n";

    my $dbm = DBM::Deep->new("$self->{dir}/$self->{file}");
    my $now = time();

    _lock_dbm($dbm);

    delete $dbm->{feed}
        if $dbm->{feed}
        && $now - $dbm->{feed}{timestamp} > $self->{feed_seconds};

    if (my $items = $dbm->{items}) {
        while (my ($id, $data) = each %$items) {
            delete $items->{$id}
                if $now - $data->{timestamp} > $self->{item_seconds};
        }
    }

    $dbm->unlock;

    return $dbm;

}

sub cache_feed {
    my $self = shift;
    return $self->_cache(
        sub { $self->{parent}->_download_feed },
        $self->{feed_seconds},
        'feed'
    );
}

sub cache_item {
    my ($self, $node, $item) = @_;
    return $self->_cache(
        sub { _textify($node, $item) },
        $self->{item_seconds},
        'items', $item->link || $item->guid
    );
}

sub _cache {
    my ($self, $generate, $duration, @keys) = @_;

    return $generate->() if !defined $duration
                         || !defined(my $dbm = $self->_dbm)
                         || grep { !defined } @keys;

    _lock_dbm($dbm);

    my $error;

    my $content = Try::Tiny::try {
        my $hash = $dbm;
        $hash = $hash->{$_} ||= { } for @keys;
        my $timestamp = $hash->{timestamp};
        my $now       = time();
        my $content;

        if (!defined $timestamp || $now - $timestamp >= $duration) {
            $content           = $generate->();
            $hash->{content}   = Encode::encode_utf8(defined $content ? $content : "");
            $hash->{timestamp} = $now;
        } else {
            $content = Encode::decode_utf8($hash->{content});
        }

        $content;

    } Try::Tiny::catch {
        $error = $_;
    } Try::Tiny::finally {
        $dbm->unlock;
    };

    die $error if $error;

    return $content;

}

sub _lock_dbm {
    my $dbm = shift;
    # Different versions of DBM::Deep do this differently, apparently...
    if ($dbm->can('lock_exclusive')) {
        $dbm->lock_exclusive;
    } else {
        $dbm->lock(DBM::Deep::LOCK_EX());
    }
}

sub _textify {
    my ($node, $item) = @_;
    my @content = $node->render($item);
    @content or @content = $node->render_default($item);
    return RSS::Tree::HtmlDocument::_render(@content);
}


1;
