BEGIN { $ENV{MOJO_REACTOR} = 'Poll' }

use Mojolicious::Lite;
use Mojo::IOLoop;

any '/feed' => sub { 
  my $c = shift;
  $c->render_later;
  my $data = { 
    entries  => [ { got_cursor => !! $c->param('cursor') } ],
    realtime => { cursor => 1 },
  };
  my $timer = Mojo::IOLoop->timer( 0.5 => sub { 
    $c->render( json => $data ) 
  });
  $c->on( finish => sub { Mojo::IOLoop->remove($timer) } );
};

any '/error' => sub {
  my $c = shift;
  $c->render_later;
  my $timer = Mojo::IOLoop->timer( 0.5 => sub {
    $c->render( text => 'nada', status => 500 );
  });
  $c->on( finish => sub { Mojo::IOLoop->remove($timer) } );
};

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new;
my $feed = $t->app->url_for('feed')->to_abs;

use Mojo::FriendFeed;

my $ua1;
subtest 'Simple' => sub {
  my $ff = Mojo::FriendFeed->new( url => $feed );
  #$ua1 = $ff->ua;
  my $ok = 0;
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  is $ok, 1;
};

my $ua2;
subtest 'Cursor' => sub {
  my $ff = Mojo::FriendFeed->new( url => $feed );
  #$ua2 = $ff->ua;
  my $ok = 0;
  $ff->on( entry => sub { 
    $ok++;
    if (pop->{got_cursor}) { Mojo::IOLoop->stop }
  });
  $ff->listen;
  Mojo::IOLoop->start;
  is $ok, 2;
};

my $ua3;
subtest 'Error' => sub {
  my $feed = $t->app->url_for('feed')->to_abs;
  my $err  = $t->app->url_for('error')->to_abs;
  my $ff = Mojo::FriendFeed->new( url => $err );
  #$ua3 = $ff->ua;
  my $ok = 0;
  $ff->on( error => sub { shift->url( $feed )->listen });
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  ok $ok;
};

done_testing;

