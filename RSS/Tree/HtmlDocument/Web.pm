package RSS::Tree::HtmlDocument::Web;

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

use parent qw(RSS::Tree::HtmlDocument);
use strict;


sub _get_content {
    my $self = shift;
    defined(my $content = $self->{downloader}->download($self->{uri}))
        or die "Failed to download URL $self->{uri}\n";
    return $content;
}


1;

__END__

=head1 NAME

RSS::Tree::HtmlDocument::Web - wraps an HTML page that is downloaded on demand

=head1 DESCRIPTION

This class is a trivial subclass of C<RSS::Tree::HtmlDocument> that
downloads HTML content on demand rather than being initialized with
static HTML.
