#!/usr/bin/env perl
use strict;
use warnings;
use AnyEvent;
use AnyEvent::Digg::Stream;
use POSIX qw(strftime);

binmode STDOUT, ":utf8";

my $cv = AnyEvent->condvar;

my $client = AnyEvent::Digg::Stream->new(
    on_event => sub {
        my $event = shift;
        printf "[%s] %s for %s\n", strftime('%F %T', localtime),
            $event->{type}, $event->{item}{link};
    },
    on_disconnect => sub {
        warn "Disconnected\n";
        $cv->send;
    }
);

$cv->recv;
