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
  Mojo::IOLoop->timer( 0.5 => sub { 
    $c->render( json => $data ) 
  });
};

any '/error' => sub {
  my $c = shift;
  $c->render_later;
  Mojo::IOLoop->timer( 0.5 => sub {
    $c->render( text => 'nada', status => 500 );
  });
};

use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new;
my $feed = $t->app->url_for('feed')->to_abs;

use Mojo::FriendFeed;

subtest 'Simple' => sub {
  my $ff = Mojo::FriendFeed->new( url => $feed );
  my $ok = 0;
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop; $ff->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  is $ok, 1;
};

subtest 'Cursor' => sub {
  my $ff = Mojo::FriendFeed->new( url => $feed );
  my $ok = 0;
  $ff->on( entry => sub { 
    $ok++;
    if (pop->{got_cursor}) { $ff->stop; Mojo::IOLoop->stop }
  });
  $ff->listen;
  Mojo::IOLoop->start;
  is $ok, 2;
};

subtest 'Error' => sub {
  my $feed = $t->app->url_for('feed')->to_abs;
  my $err  = $t->app->url_for('error')->to_abs;
  my $ff = Mojo::FriendFeed->new( url => $err );
  my $ok = 0;
  $ff->on( error => sub { shift->url( $feed )->listen });
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop; $ff->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  ok $ok;
};

done_testing;

