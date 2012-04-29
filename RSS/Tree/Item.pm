package RSS::Tree::Item;

use URI;
use strict;


sub new {
    my ($class, $parent, $item) = @_;
    bless { parent => $parent, item => $item }, $class;
}

sub title {
    return shift->{item}{title};
}

sub link {
    return shift->{item}{link};
}

sub guid {
    return shift->{item}{guid};
}

sub description {
    return shift->{item}{description};
}

sub author {
    return shift->{item}{author};
}

sub _uri {
    my $self = shift;
    return $self->{parent}->uri_for($self);
}

sub uri {
    my $self = shift;
    require URI;
    return @_ ? URI->new_abs($_[0], $self->_uri) : URI->new($self->_uri);
}

sub absolutize {
    my ($self, $element, @attr) = @_;

    my @uri = map {
        my $uri = $self->uri($element->attr($_));
        $element->attr($_, $uri->as_string);
        $uri;
    } @attr;

    return wantarray ? @uri : $uri[0];

}

sub body {
    my $self = shift;
    return exists $self->{body}
        ? $self->{body}
        : ($self->{body} = $self->_static($self->description));
}

sub page {
    my $self = shift;
    return exists $self->{page}
        ? $self->{page}
        : ($self->{page} = $self->_web($self->_uri));
}

sub content {
    my $self = shift;
    return exists $self->{content}
        ? $self->{content}
        : do {
            my $content = $self->{item}{content};
            $content = $content->{encoded}
                if ref $content eq 'HASH' && exists $content->{encoded};
            $self->{content} = $self->_static($content);
        };
}

sub findnodes {
    my ($self, $context, $path, @classes) = @_;
    require RSS::Tree::HtmlDocument;
    return $context->findnodes(
        RSS::Tree::HtmlDocument::format_path($path, @classes)
    );
}

sub _static {
    my ($self, $content) = @_;
    require RSS::Tree::HtmlDocument::Static;
    return RSS::Tree::HtmlDocument::Static->new($self->uri, $content);
}

sub _web {
    my ($self, $url) = @_;
    require RSS::Tree::HtmlDocument::Web;
    return RSS::Tree::HtmlDocument::Web->new($self->uri($url));
}

1;
