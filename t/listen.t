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
    $c->render( json => $data ) if $c->tx; 
  });
  $c->on( finish => sub { Mojo::IOLoop->remove($timer) unless $c->tx } );
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

$t->get_ok( '/feed' )
  ->status_is(200)
  ->json_is( '/entries/0/got_cursor' => 0 );

$t->get_ok( '/feed' => form => { cursor => 1 } )
  ->status_is(200)
  ->json_is( '/entries/0/got_cursor' => 1 );

use Mojo::FriendFeed;
use Mojo::URL;

subtest 'Simple' => sub {
  my $ff = Mojo::FriendFeed->new( url => Mojo::URL->new('/feed') );
  my $ok = 0;
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  is $ok, 1;
};

subtest 'Cursor' => sub {
  my $ff = Mojo::FriendFeed->new( url => Mojo::URL->new('/feed') );
  my $ok = 0;
  $ff->on( entry => sub { 
    $ok++;
    Mojo::IOLoop->stop if pop->{got_cursor};
  });
  $ff->listen;
  Mojo::IOLoop->start;
  is $ok, 2;
};

subtest 'Error' => sub {
  my $ff = Mojo::FriendFeed->new( url => Mojo::URL->new('/error') );
  my $ok = 0;
  $ff->on( error => sub { shift->url( Mojo::URL->new('/feed') )->listen });
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  ok $ok;
};

done_testing;

