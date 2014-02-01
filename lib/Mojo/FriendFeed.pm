package Mojo::FriendFeed;

use Mojo::Base 'Mojo::EventEmitter';
use v5.16;

use Mojo::UserAgent;
use Mojo::URL;

use constant DEBUG => $ENV{MOJO_FRIENDFEED_DEBUG};

has [qw/request username remote_key/] => '';

has ua => sub { Mojo::UserAgent->new->inactivity_timeout(0) };

has url => sub {
  my $self = shift;
  my $req  = $self->request || '';
  my $url  = 
    Mojo::URL
      ->new("http://friendfeed-api.com/v2/updates$req")
      ->query( updates => 1 );
  if ($self->username) {
    $url->userinfo($self->username . ':' . $self->remote_key);
  }
  return $url;
};

sub listen {
  my $self = shift;
  my $ua   = $self->ua;
  my $url  = $self->url;
  warn "Subscribing to: $url\n" if DEBUG;

  $self->{stop} = 0;

  $ua->get( $url => sub {
    my ($ua, $tx) = @_;

    return if $self->{stop};

    warn "Received message: @{[$tx->res->body]}" if DEBUG;

    my $json = $tx->res->json;
    unless ($tx->success and $json) {
      $self->emit( error => $tx );
      return;
    }

    $self->emit( entry => $_ ) for @{ $json->{entries} };

    return if $self->{stop};

    if ($json->{realtime}) {
      my $next = $url->clone->query(cursor => $json->{realtime}{cursor});
      $ua->get( $next => __SUB__ );
    } 
  });
}

sub stop { shift->{stop} = 1 }

1;

=head1 NAME

Mojo::FriendFeed - A non-blocking FriendFeed listener for Mojolicious

=head1 SYNOPSIS

 use Mojo::Base -strict;
 use Mojo::IOLoop;
 use Mojo::FriendFeed;
 use Data::Dumper;

 my $ff = Mojo::FriendFeed->new( request => '/feed/cpan' );
 $ff->on( entry => sub { say Dumper $_[1] } );
 $ff->listen;

 Mojo::IOLoop->start;

=head1 DESCRIPTION

A simple non-blocking FriendFeed listener for use with the Mojolicious toolkit.
Its code is highly influenced by Miyagawa's L<AnyEvent::FriendFeed::Realtime>.

=head1 EVENTS

Mojo::FriendFeed inherits all events from L<Mojo::EventEmitter> and implements the following new ones.

=head2 entry

 $ff->on( entry => sub {
   my ($ff, $entry) = @_;
   ...
 });

Emitted when a new entry has been received, once for each entry.
It is passed the instance and the data decoded from the JSON response.

=head2 error

 $ff->on( error => sub {
   my ($ff, $tx) = @_;
   ...
 });

Emitted for transaction errors. 
It is passed the instance and the L<Mojo::Transaction> object which encountered the error.
Note that after emitting the error event, the C<listen> method exits, use this hook to re-attach if desired.

=head1 ATTRIBUTES

Mojo::FriendFeed inherits all attributes from L<Mojo::EventEmitter> and implements the following new ones.

=head2 request 

The feed to request. Default is an empty string.

=head2 ua

An instance of L<Mojo::UserAgent> for making the feed request.

=head2 url

The (generated) url of the feed. Using the default value is recommended.

=head2 username 

Your FriendFeed username. If set, authentication will be used.

=head2 remote_key

Your FriendFeed API key. Unused unless C<username> is set.

=head1 METHODS

Mojo::FriendFeed inherits all methods from L<Mojo::EventEmitter> and implements the following new ones.

=head2 listen

Connects to the feed and attaches events. Note that this does not start an IOLoop and will not block.

=head2 stop

Stops the listener at the next available opportunity.
