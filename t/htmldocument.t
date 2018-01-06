#!/usr/bin/perl

use RSS::Tree::HtmlDocument;
use Test::Exception;
use Test::More;
use URI;
use strict;

my $uri = URI->new('gopher://foo.bar/');

my $doc = RSS::Tree::HtmlDocument->new($uri, <<'EOT');
<html>
  <head>
  </head>
  <body>
  </body>
</html>
EOT

my $uri2 = $doc->uri;

is($uri2, $uri);
ok($uri != $uri2);

throws_ok { RSS::Tree::HtmlDocument->new('/', "") } qr/relative URI/;

$doc = RSS::Tree::HtmlDocument->new(undef, "<html></html>");

$uri2 = $doc->absolute_uri('gopher://go.pher/');

is($uri2, 'gopher://go.pher/');

throws_ok { $doc->absolute_uri('/path') } qr/cannot convert/i;

$doc = RSS::Tree::HtmlDocument->new('gopher://gop.her/');

$uri2 = $doc->absolute_uri('/foo');

is($uri2, 'gopher://gop.her/foo');

$doc = RSS::Tree::HtmlDocument->new('gopher://mack.n.tosh/', \&content);

my @guts = $doc->guts;

is(2, scalar @guts);
is('p', $guts[0]->tag);
is('div', $guts[1]->tag);

$doc = RSS::Tree::HtmlDocument->new(undef, \&doc);

is(8, () = $doc->find('//*')); # all explicit tags, plus the implicit BODY and HTML tags
is(3, () = $doc->find('//li'));
is(3, () = $doc->find('//*[@id="three"]/ancestor::*')); # UL, BODY, HTML
is('span', ($doc->find('//*[%s]', 'x'))[0]->tag);

$doc->remove('//li[span[%s]]', 'x');
is(2, () = $doc->find('//li'));
$doc->remove('//li[not(@id)]');
is(2, () = $doc->find('//li'));

$doc = RSS::Tree::HtmlDocument->new(undef, \&doc);

$doc->truncate('//span[%s and %s]/parent::*', 'x', 'y');
is(1, () = $doc->find('//li'));

####################

sub content {
    <<'EOT';
<p>This is content, of a sort.</p>
<div>This is a div.</div>
EOT
}

sub doc {
    <<'EOT';
<ul>
<li id="one">one</li>
<li id="two"><span class="x y">two</span></li>
<li id="three">three</li>
</ul>
EOT
}
