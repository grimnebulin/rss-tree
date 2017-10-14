#!/usr/bin/perl

use RSS::Tree;
use Test::More;
use strict;

delete @ENV{ grep /^RSS_TREE_/, keys %ENV };

# Basic test

eval { RSS::Tree->new->run };
like($@, qr/No RSS feed defined/);

{

package BasicTree;

use base 'RSS::Tree';

sub new {
    shift->SUPER::new(
        feed => 'test://test.test/test.rss',
        agent => MyAgent->new,
        @_
    );
}

}


{

package MyAgent;

sub new {
    bless { }, shift;
}

}

BasicTree->new->run;
