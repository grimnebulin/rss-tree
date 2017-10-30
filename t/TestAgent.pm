package TestAgent;

use File::Spec;
use HTTP::Response;
use URI;
use XML::RSS;
use strict;


sub new {
    my ($class, $dir, $base_url) = @_;
    bless { dir => $dir, base_url => URI->new($base_url) }, $class;
}

sub get {
    my ($self, $url) = @_;
    $url = URI->new($url);
    my $rel = $url->rel($self->{base_url});
    return _404() if $rel == $url || $rel !~ /^[-\w.]+\z/;
    my $path = File::Spec->catfile($self->{dir}, $rel);
    if (open my $fh, '<', $path) {
        local $/;
        my $content = <$fh>;
        return HTTP::Response->new(200, undef, undef, $content);
    } else {
        return _404();
    }
}

sub _404 {
    HTTP::Response->new(404);
}


1;
