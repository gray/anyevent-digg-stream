package AnyEvent::Digg::Stream;

use strict;
use warnings;

use AnyEvent::HTTP;
use Carp qw(croak);
use URI;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

sub new {
    my ($class, %params) = @_;

    my $on_error      = $params{on_erorr}      || sub { die @_ };
    my $on_eof        = $params{on_eof}        || sub { };
    my $on_event      = $params{on_event}      || sub { };
    my $on_comment    = $params{on_comment}    || sub { };
    my $on_digg       = $params{on_digg}       || sub { };
    my $on_submission = $params{on_submission} || sub { };

    my %events = (
        digg       => $on_digg,
        comment    => $on_comment,
        submission => $on_submission,
    );

    my @events;
    for my $event (keys %{{map { $_=>1 } @{$params{events}} }}) {
        croak "Unknown event type: $event\n" unless $events{$event};
        push @events, $event;
    }

    my $uri = URI->new('http://services.digg.com/2.0/stream');
    $uri->query_form(
        format => 'json',
        3 == @events ? () : @events ? join(',', @events) : (),
    );

    my $conn = http_request(
        GET     => $uri,
        headers => {
            'User-Agent' => __PACKAGE__ . "/$VERSION",
            Referer      => undef,
        },
        on_header => sub {
            my ($headers) = @_;
            if ('200' ne $headers->{Status}) {
                $on_error->("$headers->{Status}: $headers->{Reason}");
                return;
            }
            if ('application/json' ne $headers->{'content-type'}) {
                $on_error->(
                    "Unexpected Content-Type: $headers->{'content-type'}"
                );
                return;
            }
            return 1;
        },
        want_body_handle => 1,
        sub {
            my ($handle, $headers) = @_;
            unless (defined $handle) {
                $on_error->("$headers->{Status}: $headers->{Reason}");
            }

            $handle->on_error(sub {
                undef $handle;
                $on_error->($_[2]);
            });
            $handle->on_eof(sub {
                undef $handle;
                $on_eof->(@_);
            });
            $handle->on_read(sub {
                $handle->push_read(json => sub {
                    my (undef, $data) = @_;
                    $on_event->($data);
                    ($events{$data->{type}} || sub {})->($data);
                });
            });
        }
    );

    return $conn;
}


1;

__END__

=head1 NAME

AnyEvent::Digg::Stream - AnyEvent client for the Digg streaming API

=head1 SYNOPSIS

    use AnyEvent::Digg::Stream;

    my $client = AnyEvent::Digg::Stream->new(
        events        => [qw( digg submission comment )],
        on_event      => sub { },
        on_digg       => sub { },
        on_submission => sub { },
        on_comment    => sub { },
    );

=head1 DESCRIPTION

The C<AnyEvent::Digg::Stream> module is an C<AnyEvent> client for the Digg
streaming API.

=head1 METHODS

=head2 new

    $client = AnyEvent::Digg::Stream->new(%args)

Creates a new client. The following named arguments are accepted:

=over

=item B<events>

A list of the desired event types to include in the stream. Any of the
following are valid: B<digg>, B<submission>, B<comment>. Default is to
include all types.

=item B<on_event>

Callback to execute for any event type.

=item B<on_digg>

=item B<on_submission>

=item B<on_comment>

Callback to executute for the related event type.

=item B<on_error>

=item B<on_eof>

Callbacks to execute on errors.

=back

=head1 SEE ALSO

L<AnyEvent::HTTP>

L<http://developers.digg.com/version2/stream>

=head1 REQUESTS AND BUGS

Please report any bugs or feature requests to
L<http://rt.cpan.org/Public/Bug/Report.html?Queue=AnyEvent-Digg-Stream>.
I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::Digg::Stream

You can also look for information at:

=over

=item * GitHub Source Repository

L<http://github.com/gray/anyevent-digg-stream>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-Digg-Stream>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-Digg-Stream>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/Public/Dist/Display.html?Name=AnyEvent-Digg-Stream>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-Digg-Stream/>

=back

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010-2011 gray <gray at cpan.org>, all rights reserved.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 AUTHOR

gray, <gray at cpan.org>

=cut
