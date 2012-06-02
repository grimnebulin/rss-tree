package RSS::Tree::Node;

use Carp;
use strict;

sub new {
    my ($class, $name, $title) = @_;

    !defined $name
        or $name =~ /^\w+\z/
        or croak qq(Invalid node name "$name"\n);

    bless {
        name     => $name,
        title    => $title,
        children => [ ],
        test     => undef,
    }, $class;

}

sub name {
    return shift->{name};
}

sub title {
    return shift->{title};
}

sub add {
    my $self = shift;
    push @{ $self->{children} }, @_;
    return $self;
}

sub process {
    my ($self, $item, $stop) = @_;
    for my $child ($self->_children) {
        my $node = $child->process($item, $stop);
        return $node if $node || !defined $node;
    }
    return $self if $self->test($item);
    return if defined $stop && defined $self->{name} && $self->{name} eq $stop;
    return 0;
}

sub match_title {
    my ($self, $regex) = @_;
    $self->{test} = eval 'sub { _trim($_[0]->title) =~ /$regex/o }';
    die $@ if $@;
    return $self;
}

sub match_author {
    my ($self, $regex) = @_;
    $self->{test} = eval 'sub { _trim($_[0]->author) =~ /$regex/o }';
    return $self;
}

sub test {
    my ($self, $item) = @_;
    return !$self->{test} || $self->{test}->($item);
}

sub render {
    my ($self, $item) = @_;
    return $item->description;
}

sub uri_for {
    my ($self, $item) = @_;
    return $item->link;
}

sub new_element {
    my $self = shift;
    require HTML::Element;
    return HTML::Element->new_from_lol([ @_ ]);
}

sub findnodes {
    my ($self, $context, $path, @classes) = @_;
    require RSS::Tree::HtmlDocument;
    return $context->findnodes(
        RSS::Tree::HtmlDocument::_format_path($path, @classes)
    );
}

sub _children {
    return @{ shift->{children} };
}

sub _write_program {
    my ($self, $tree_class, @use_class) = @_;

    $_->_write_program($tree_class, @use_class) for $self->_children;

    return if !defined $self->{name};

    my $filename = "$self->{name}.pl";

    open my $fh, '>', $filename
        or die "Can't open file $filename for writing: $!\n";

    print $fh "#!/usr/local/bin/perl -CO\n",
              "#\n",
              "use ", @use_class ? $use_class[0] : $tree_class, ";\n",
              "use strict;\n\n",
              "print qq(Content-Type: text/xml\\n\\n), ",
              "$tree_class->new->run('$self->{name}');\n";
    close $fh;

    chmod 0744, $filename;

}

sub _trim {
    my $str = shift;
    $str =~ s/^\s+//;
    $str =~ s/\s+\z//;
    return $str;
}


1;

__END__

=head1 NAME

RSS::Tree::Node - nodes in an RSS::Tree tree

=head1 SYNOPSIS

    package MyNode;
    use base qw(RSS::Tree::Node);

