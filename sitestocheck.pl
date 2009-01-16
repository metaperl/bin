#!/usr/bin/perl

use strict;
use warnings;

use LWP::Simple;
use HTTP::Request::Common qw(POST);
use LWP::UserAgent;
use Mail::Message;

my $site = 'http://www.gimblerus.com/cgi-bin/x?task=home';

sub check {
  my $site = shift or die 'no site supplied' ;

  my $ua = LWP::UserAgent->new;
  my $req = POST 'http://validator.w3.org/checklink/',  [ 
    uri       => $site, 
    summary   => 'on',
    hide_type => 'all',
    recursive => 'on',
    depth     => '-1',
    check     => 'Check'
   ];

  warn $req->as_string;

  $ua->request($req);
}

sub mail {
  my ($site, $content) = @_;

  my $message = Mail::Message->build  ( 
    From       => 'checklink@metaperl.com',
    To         => 'metaperl@gmail.com',
    'Content-Type' => 'text/html',
    Subject    => "Checklink Results: $site",
    'X-Mailer' => 'Automatic mailing system',
    data       => [ $content ]
   );

  $message->send;
}

warn 1;
my $response = check $site;
warn 2;

if ($response) { 
  mail $site, $response->content;
} else {
  die "could not browse $site";
}

warn 3;
