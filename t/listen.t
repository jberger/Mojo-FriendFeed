BEGIN { $ENV{MOJO_REACTOR} = 'Poll' }

use Mojolicious::Lite;
use Mojo::IOLoop;

any '/feed' => sub { 
  my $c = shift;
  $c->render_later;
  Mojo::IOLoop->timer( 0.5 => sub { 
    $c->render( json => { entries => [ {} ] } ) 
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

use Mojo::FriendFeed;

subtest 'Simple' => sub {
  my $ff = Mojo::FriendFeed->new( url => $t->app->url_for('feed')->to_abs );
  my $ok = 0;
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  ok $ok;
};

subtest 'Error' => sub {
  my $feed = $t->app->url_for('feed')->to_abs;
  my $err  = $t->app->url_for('error')->to_abs;
  my $ff = Mojo::FriendFeed->new( url => $err );
  my $ok = 0;
  $ff->on( error => sub { shift->url( $feed )->listen });
  $ff->on( entry => sub { $ok++; Mojo::IOLoop->stop });
  $ff->listen;
  Mojo::IOLoop->start;
  ok $ok;
};

done_testing;

