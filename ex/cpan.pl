#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::FriendFeed;
use Mojo::IOLoop;
use Mojo::DOM;
use Mojo::URL;
use Mojo::IRC;

use Getopt::Long;

GetOptions(
  'channel=s'  => \(my $chan   = 'release'),
  'nickname=s' => \(my $nick   = 'release_bot'),
  'pattern=s'  => \my $pattern,
  'server=s'   => \(my $server = 'irc.perl.org:6667'),
  'user=s'     => \(my $user   = 'new cpan releases'), 
);

$pattern = qr/$pattern/ if $pattern;

my $send = sub { shift->write( privmsg => shift, ":@_" ) };

my $irc = Mojo::IRC->new(
  nick   => $nick,
  user   => $user,
  server => $server,
);
$irc->register_default_event_handlers;
$irc->connect(sub{
  my ($irc, $err) = @_;
  if ($err) {
    warn $err;
    exit 1;
  }
  $irc->write( join => "#$chan" );
});

my $ff = Mojo::FriendFeed->new( request => '/feed/cpan' );

$ff->on( entry => sub {
  my ($self, $entry) = @_;
  my $dom = Mojo::DOM->new($entry->{body});
  my $file_url = Mojo::URL->new($dom->at('a')->{href});
  my ($pauseid, $file) = @{$file_url->path->parts}[-2,-1];
  $file =~ s/\.tar\.gz//;
  
  my $msg = $dom->text . " http://metacpan.org/release/$pauseid/$file";
  if ($pattern and $msg !~ $pattern) {
    return;
  }

  $irc->$send( '#release' => $msg );
  say $msg;
});

$ff->on( error => sub { warn "$_[1]\n"; shift->listen } );

$ff->listen;

Mojo::IOLoop->start;

