package RSS::Tee;

use Carp;
use Errno;
use Fcntl qw(:flock);
use File::stat;
use strict;

my $DEFAULT_CACHE_TIME = 60;


sub new {
    my ($class, $source_url, $default, $title, $cachefile, $cachetime) = @_;

    my $self = bless {
        source_url => $source_url,
        cachefile  => $cachefile,
        cachetime  => defined($cachetime) ? $cachetime : $DEFAULT_CACHE_TIME,
        splits     => [ ],
    }, $class;

    my $defsplit = RSS::Tee::_Split->_new($self, $default, $title);
    $self->{default} = $defsplit;
    $self->{by_name} = { $default => $defsplit };

    return $self;

}

sub _check_name {
    my $name = shift;
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;
    $name =~ /^\w+\z/
        or croak qq(Invalid name "$name"\n);
}

sub split {
    my ($self, $name, $title) = @_;

    _check_name($name);

    exists $self->{by_name}{$name}
        and croak qq(Split "$name" already defined\n);

    my $split = RSS::Tee::_Split->_new($self, $name, $title);

    push @{ $self->{splits} }, $split;
    $self->{by_name}{$name} = $split;

    return $split;

}

sub _splits {
    return @{ shift->{splits} };
}

sub write_scripts {
    my $self = shift;
    $_->_write_script for $self->_splits, $self->{default};
}

sub _get_rss {
    my $self = shift;
    my $now  = time();

    return $self->_retrieve_rss if !defined $self->{cachefile};

    my $content;
    my $fh;

    if (open $fh, '+<', $self->{cachefile}) {
        flock $fh, LOCK_EX;
        my $stat = stat($fh);
        if ($now - $stat->mtime <= $self->{cachetime}) {
            $content = do { local $/; <$fh> };
        }
    } elsif ($!{ENOENT}) {
        open $fh, '>', $self->{cachefile}
            or croak "Can't open file $self->{cachefile}: $!\n";
        flock $fh, LOCK_EX;
    } else {
        croak "Can't open file $self->{cachefile}: $!\n";
    }

    if (!defined $content) {
        $content = $self->_retrieve_rss;
        print $fh $content;
    }

    return $content;

}

sub _retrieve_rss {
    my $self = shift;
    require LWP::Simple;
    defined(my $content = LWP::Simple::get($self->{source_url}))
        or croak "Failed to retrieve RSS feed from $self->{source_url}\n";
    return $content;
}

sub run {
    my ($self, $name) = @_;
    _check_name($name);

    defined(my $target = $self->{by_name}{$name})
        or croak qq(No such split "$name" defined\n);

    my $content = $self->_get_rss;

    require XML::RSS;

    my $rss    = XML::RSS->new->parse($content);
    my $items  = $rss->{items};
    my @splits = ($self->_splits, $self->{default});
    my $index  = 0;

    while ($index < @$items) {
        my $item = $items->[$index];
        for my $split (@splits) {
            next if !$split->_match($item);
            if ($split == $target) {
                ++$index;
            } else {
                splice @$items, $index, 1;
            }
            last;
        }
    }

    $rss->{channel}{title} = $rss->{channel}{description} = $target->{title};

    return $rss->as_string;

}

{

package RSS::Tee::_Split;

# use Errno;

sub _new {
    my ($class, $parent, $name, $title) = @_;

    bless {
        name  => $name,
        title => $title,
        test  => sub { 1 },
        parent_class => ref $parent,
    }, $class;

}

sub name {
    return shift->{name};
}

sub title {
    my ($self, $regex) = @_;
    $self->{test} = eval 'sub { _trim($_[0]{title}) =~ /$regex/o }';
    return $self;
}

sub _trim {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+\z//;
    return $str;
}

sub _match {
    my ($self, $item) = @_;
    return $self->{test}->($item);
}

sub _write_script {
    my $self = shift;
    my $filename = "$self->{name}.pl";

    open my $fh, '>', $filename
        or die "Can't open file $filename for writing: $!\n";

    print $fh "#!/usr/local/bin/perl\n",
              "BEGIN { open STDERR, '>/dev/null' }\n",
              "use lib '/home/lurch/perl';\n",
              "use lib '/home/lurch/perl/lib/perl5/site_perl/5.8.8';\n",
              "use $self->{parent_class};\n",
              "use strict;\n\n",
              "print qq(Content-Type: text/xml\\n\\n);",
              "my \$xml = $self->{parent_class}->new->run('$self->{name}');\n",
              "\$xml =~ s/encoding=\"\"/encoding=\"utf-8\"/;\n",
              "print \$xml;\n";
    close $fh;

    chmod 0744, $filename;

}

}

1;
