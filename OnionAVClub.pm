package OnionAVClub;

use RSS::Tee;
use strict;

our @ISA = qw(RSS::Tee);


sub new {
    my $class = shift;

    my $self = $class->SUPER::new(
        'http://www.avclub.com/feed/daily', 'avclub', 'AV Club',
        "$ENV{HOME}/avclub-cache", 10
    );

    $self->split('tv_i_watch', 'TV I Watch')
         ->title('^TV:.*(?:American Dad|Archer|South Park|Big Bang Theory|Dexter)');

    $self->split('tv', 'TV')
         ->title('^TV:');

    $self->split('films', 'Films')
         ->title('Movie Review');

    $self->split('redmeat', 'Red Meat')
         ->title('Red Meat');

    $self->split('geekery', 'Geekery')
         ->title('Gateways to Geekery');

    $self->split('greatjob', 'Great Job')
         ->title('Great Job, Internet');

    $self->split('books', 'Books')
         ->title('^Books:');

    return $self;

}

1;
