#!/usr/bin/env perl

use Mojo::Base -strict;

use DDP;
use Mojo::FriendFeed;
use Mojo::IOLoop;
use Mojo::DOM;
use Mojo::URL;
use Mojo::IRC;

my $send = sub { shift->write( privmsg => shift, ":@_" ) };

my $irc = Mojo::IRC->new(
  nick   => 'release_bot',
  user   => 'new cpan releases',
  server => 'irc.perl.org:6667',
);
$irc->register_default_event_handlers;
$irc->connect(sub{
  my ($irc, $err) = @_;
  if ($err) {
    warn $err;
    exit 1;
  }
  $irc->write( join => '#release' );
});

my $ff = Mojo::FriendFeed->new( request => '/feed/cpan' );

$ff->on( entry => sub {
  my ($self, $entry) = @_;
  my $dom = Mojo::DOM->new($entry->{body});
  my $file_url = Mojo::URL->new($dom->at('a')->{href});
  my ($pauseid, $file) = @{$file_url->path->parts}[-2,-1];
  $file =~ s/\.tar\.gz//;
  
  my $msg = $dom->text . " http://metacpan.org/release/$pauseid/$file";
  $irc->$send( '#release' => $msg );
  say $msg;
});

$ff->on( error => sub { say scalar $_[1]->error } );

$ff->listen;

Mojo::IOLoop->start;

