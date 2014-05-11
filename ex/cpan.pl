#!/usr/bin/env perl

use Mojo::Base -strict;

use Mojo::FriendFeed;
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::URL;
use Mojo::IRC;
use List::Util 'first';

use DDP;

use Getopt::Long;

my $conf_file = shift or die "A configuration file is required.\n";

my %defaults = (
  nickname => 'release_bot',
  server   => 'irc.perl.org:6667',
  user     => 'new cpan releases',
  jobs     => [],
);

my %conf = (%defaults, %{ do $conf_file });

my $ua = Mojo::UserAgent->new;

my $join = sub { shift->write( join => shift ) };
my $send = sub { shift->write( privmsg => shift, ":@_" ) };

sub parse {
  my $body = shift;
  my ($dist, $version) = $body =~ /^(\S+) (\S+)/;
  my $dom = Mojo::DOM->new($body);
  my $file_url = Mojo::URL->new($dom->at('a')->{href});
  my $pause_id = $file_url->path->parts->[-2];

  my $deps = $ua->get("http://api.metacpan.org/v0/release/$dist")->res->json('/dependency') || [];
  my @deps = map { $_->{module} } @$deps; # } # highlight fix

  return {
    dist     => $dist,
    version  => $version,
    file_url => $file_url,
    pause_id => $pause_id,
    text     => $dom->text,
    deps     => \@deps,
  };
}

my $irc = Mojo::IRC->new(
  nick   => $conf{nickname},
  user   => $conf{user},
  server => $conf{server},
);
$irc->register_default_event_handlers;
$irc->connect(sub{
  my ($irc, $err) = @_;
  if ($err) {
    warn $err;
    exit 1;
  }
  foreach my $job (@{ $conf{jobs} }) {
    next unless my $chan = $job->{channel};
    $irc->$join($chan) if $chan =~ /^#/;
  }
});

my $ff = Mojo::FriendFeed->new( request => '/feed/cpan' );

$ff->on( entry => sub {
  my ($self, $entry) = @_;
  my $data = parse($entry->{body});
  
  my $msg = $data->{text} . " http://metacpan.org/release/$data->{pause_id}/$data->{dist}-$data->{version}";
  say $msg;
  p $data;

  my @deps = @{ $data->{deps} || [] };

  for my $job (@{ $conf{jobs} }) {
    if (my $filter = $job->{dist}) {
      next unless $data->{dist} =~ $filter;
    }
    if (my $filter = $job->{deps}) {
      next unless first { $_ =~ $filter } @deps;
    }
    $irc->$send( $job->{channel} => $msg );
  }
});

$ff->on( error => sub { warn "$_[1]\n"; shift->listen } );

$ff->listen;

Mojo::IOLoop->start;

