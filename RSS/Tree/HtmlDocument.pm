# Should probably be "DocumentFragment" instead...
package RSS::Tree::HtmlDocument;

use URI;
use overload '""' => 'as_str', fallback => 1;
use strict;


sub new {
    my ($class, $uri, $downloader, $content) = @_;
    bless {
        uri        => $uri,
        downloader => $downloader,
        exposed    => undef,
        defined $content ? (content => $content) : (),
    }, $class;
}

sub content {
    my $self = shift;
    return exists $self->{content}
        ? $self->{content}
        : ($self->{content} = $self->_get_content);
}

sub tree {
    my $self = shift;
    require HTML::TreeBuilder::XPath;
    return $self->{tree} ||=
        HTML::TreeBuilder::XPath->new_from_content($self->content);
}

sub as_str {
    my $self = shift;
    return $self->{exposed} ? _render_tree($self->tree) : $self->content;
}

sub findvalue {
    my $self = shift;
    return $self->tree->findvalue(_path(@_));
}

sub findnodes {
    my $self = shift;
    $self->{exposed} = 1;
    return $self->tree->findnodes(_path(@_));
}

sub follow {
    my $self = shift;
    my $url = $self->findvalue(@_) or return;
    require RSS::Tree::HtmlDocument::Web;
    return RSS::Tree::HtmlDocument::Web->new(
        URI->new_abs($url, $self->{uri}), $self->{downloader}
    );
}

sub absolutize {
    my ($self, $element, $attr) = @_;
    $element->attr($attr, URI->new_abs($element->attr($attr), $self->{uri}));
    return $element;
}

sub _render_tree {
    my $tree = shift;
    my $tags = { };
    return join "", map { $_->as_HTML("", undef, $tags) } $tree->guts;
}

sub format_path {
    my ($path, @classes) = @_;
    return sprintf $path, map _has_class($_), @classes;
}

sub _has_class {
    my $class = shift;
    return sprintf 'contains(concat(" ",normalize-space(@class)," ")," %s ")',
                   $class;
}

sub _path {
    my ($path, @classes) = @_;
    return @classes ? format_path($path, @classes) : $path;
}


1;
