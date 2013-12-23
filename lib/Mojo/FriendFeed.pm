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
  my $url = 
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
  my $ua = $self->ua;
  my $url = $self->url;
  say "Subscribing to: $url" if DEBUG;

  $ua->get( $url => sub {
    my ($ua, $tx) = @_;

    say "Received message: " . $tx->res->body if DEBUG;

    my $json = $tx->res->json;
    unless ($tx->success and $json) {
      $self->emit( error => $tx );
      return;
    }

    $self->emit( entry => $_ ) for @{ $json->{entries} };

    if ($json->{realtime}) {
      my $next = $url->clone->query(cursor => $json->{realtime}{cursor});
      $ua->get( $next => __SUB__ );
    } 
  });
}

1;

