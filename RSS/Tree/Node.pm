package RSS::Tree::Node;

use Carp;
use strict;

sub new {
    my ($class, $name, $title, %opts) = @_;

    !defined $name
        or $name =~ /^\w+\z/
        or croak qq(Invalid node name "$name"\n);

    bless {
        name     => $name,
        title    => $title,
        children => [ ],
        test     => undef,
        opts     => \%opts,
    }, $class;

}

sub name {
    return shift->{name};
}

sub Title {
    return shift->{title};
}

sub add {
    my ($self, $child) = @_;
    push @{ $self->{children} }, $child;
    return $self;
}

sub add_to {
    my ($self, $parent) = @_;
    $parent->add($self);
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

sub title {
    my ($self, $regex) = @_;
    $self->{test} = eval 'sub { _trim($_[0]->title) =~ /$regex/o }';
    return $self;
}

sub test {
    my ($self, $item) = @_;
    return !$self->{test} || $self->{test}->($item);
}

sub render {
    my ($self, $item) = @_;
    return $item->body;
}

sub _children {
    return @{ shift->{children} };
}

sub _write_program {
    my ($self, $tree_class, $prelude) = @_;

    $_->_write_program($tree_class, $prelude) for $self->_children;

    return if !defined $self->{name};

    my $filename = "$self->{name}.pl";

    open my $fh, '>', $filename
        or die "Can't open file $filename for writing: $!\n";

    print $fh "#!/usr/local/bin/perl\n",
              "BEGIN { binmode STDOUT, ':utf8' }\n",
              defined $prelude ? ($prelude, "\n") : (),
              "use $tree_class;\n",
              "use strict;\n\n",
              "my \$xml = $tree_class->new->run('$self->{name}');\n",
              "\$xml =~ s/encoding=\"\"/encoding=\"utf-8\"/;\n",
              "print qq(Content-Type: text/xml\\n\\n), \$xml;\n";
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
