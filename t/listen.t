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
    $c->render( json => $data ); 
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

$t->get_ok( '/feed' )
  ->status_is(200)
  ->json_is( '/entries/0/got_cursor' => 0 );

$t->get_ok( '/feed' => form => { cursor => 1 } )
  ->status_is(200)
  ->json_is( '/entries/0/got_cursor' => 1 );

$t->get_ok( '/error' )
  ->status_is(500);
  
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

