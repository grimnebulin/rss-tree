package RSS::Tree::Item;

use strict;


sub new {
    my ($class, $item) = @_;
    bless { item => $item }, $class;
}

sub title {
    return shift->{item}{title};
}

sub link {
    return shift->{item}{link};
}

sub description {
    return shift->{item}{description};
}

sub uri {
    my $self = shift;
    require URI;
    return @_ ? URI->new_abs($_[0], $self->link) : URI->new($self->link);
}

sub body {
    my $self = shift;
    return RSS::Tree::Item::_HtmlTree::Static->new($self->description);
}

sub page {
    my $self = shift;
    return RSS::Tree::Item::_HtmlTree::Net->new($self->link);
}

{

package RSS::Tree::Item::_HtmlTree;

use overload '""' => 'content', fallback => 1;

sub new {
    my $class = shift;
    bless { }, $class;
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

sub findnodes {
    my ($self, $path) = @_;
    return $self->tree->findnodes($path);
}

sub findvalue {
    my ($self, $path) = @_;
    return $self->tree->findvalue($path);
}

}

{

package RSS::Tree::Item::_HtmlTree::Static;

our @ISA = qw(RSS::Tree::Item::_HtmlTree);

sub new {
    my ($class, $content) = @_;
    my $self = $class->SUPER::new;
    $self->{content} = $content;
    return $self;
}

}

{

package RSS::Tree::Item::_HtmlTree::Net;

our @ISA = qw(RSS::Tree::Item::_HtmlTree);

sub new {
    my ($class, $url) = @_;
    my $self = $class->SUPER::new;
    $self->{url} = $url;
    return $self;
}

sub _get_content {
    my $self = shift;
    require LWP::Simple;
    defined(my $content = LWP::Simple::get($self->{url}))
        or die "Failed to download URL $self->{url}\n";
    return $content;
}

}

1;
