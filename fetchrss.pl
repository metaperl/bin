#!/usr/bin/perl -w
# fetchrss.pl v1.17 - convert items in an rss feed to email messages
# Copyright 2002 Doug Alcorn <doug@lathi.net>

# You are free to use this software under the terms of the GNU Public
# License.

use strict;
use vars qw ($version $debug $count $ua %smtp);
use subs qw(&parse &load_msg_cache &get_feed &get_rss &flatten_item &build_message &send_message);
use LWP::UserAgent;
use XML::RSS;
use Net::SMTP;
use Digest::MD5 qw(md5_hex);

my $version = "1.17";
my $debug = $ENV{RSS_DEBUG};
my $count = 0;


######
#
#  Global variables
#
######

my $arg = shift;
$arg = '' unless ($arg);
my $dir = '';
if ($arg eq "-q") {
    $dir = shift;
    $dir = "$ENV{HOME}/.fetchrss" unless ($dir);
    my $pidfile = "$dir/pid";
    if (-e $pidfile) {
	open PIDFILE, $pidfile or
	    die "Can't read '$pidfile', $!\n";
	my $pid = <PIDFILE>;
	my $cmd = "kill $pid";
	system($cmd) and
	    die "Couldn't kill $pid";
	exit;
    }
} else {
    $dir = "$ENV{HOME}/.fetchrss" unless ($arg);
}
my $ini = "$dir/fetchrss.ini";

die "Can't open initialization file '$ini', $!\n"
   unless (-f "$ini");

my ($feedfile, $datafile, $smtp_address, $smtp_host, $smtp_email, $timeout, $proxy) = &parse ($ini);
my %smtp = ( host => $smtp_host, address => $smtp_address, email => $smtp_email,);
my $daemon = "";
my $freq = 1200;
my $ua = LWP::UserAgent->new;
$ua->agent("FetchRSS.pl v$version - http://www.lathi.net/FetchRSS");
$timeout = ($timeout) ? $timeout : 30;
$ua->timeout($timeout);
$ua->proxy(http => $proxy);

#####
#
# Sub-routines
#
#####

# main proceedure execed at end
sub main_proc ($$$$$) { 
  my ($dir, $feedfile, $datafile, $daemon, $freq) = @_;

  my $pidfile = "$dir/pid";
   if ($daemon) {
      $debug = "";
      require Proc::Daemon;
      Proc::Daemon::Init();
      open PIDFILE, ">$pidfile";
      print PIDFILE $$;
      close PIDFILE;
      print $pidfile, "\n";
   }

   my %feed = load_feeds ("$dir/$feedfile");
   die "No valid RSS feeds defined in '$feedfile'\n"
      unless (keys %feed);

   get_cache ("$dir/$datafile", \%feed);

   do {
      my $time = time;
      process_feeds ($dir, \%feed);
      write_cache ($dir, $datafile, \%feed);
      my $delta = time - $time;
      if ($daemon) { sleep ($freq - $delta); }
   } while ($daemon);

   0;
}

# read the feed file and build a hash of the data therein
sub load_feeds ($) {
   my $feedfile = shift;
   my %feed;

   open FEED, "$feedfile" or die "Can't read '$feedfile' file, $!\n";
   while (<FEED>) {
      next if (/^\s*\#/);
      chomp;
      my ($name, $url, $credentials) = split;
      unless ( $name and $url) {
         warn "Invalid feed file format: $_";
         next;
      }
      $feed{$name} = { url => $url, credentials => $credentials};;
   }
   close FEED;
   return %feed;
}

# read in the cache of etags and last-modified for each feed this
# keeps us from unnecessarily downloading the feed if it hasn't
# changed
sub get_cache ($$) {
   my ($datafile, $feedref) = @_;
   if (open DATA, "$datafile") {
      while (<DATA>) {
         chomp;
         my ($name, $date, $etag) = split /\t/;
         next unless ($name);
         next unless (exists $feedref->{$name});
         $feedref->{$name}{date} = $date;
         $feedref->{$name}{etag} = $etag;
      }
      close DATA;
   } else {
      warn "Can't read '$datafile' file, $!\n";
   }
}

# load in the cache of individual item md5sums.  keeps us from sending
# the same message over and over again
sub load_msg_cache($$$) {
   my ($dir, $feed, $feedref) =@_;
   my $cachefile = "$dir/$feed";
   if (-f "$cachefile" ) {
      open FEED, "$cachefile" or do {
         warn "Can't read '$cachefile', $!\n";
         return -1;
      };
      $feedref->{$feed}{cache} = {} unless (exists $feedref->{$feed}{cache});
      while (<FEED>) {
         chomp;
         $feedref->{$feed}{cache}{$_} = 'true';
      }
      close FEED;
   }
   return 0;
}

# actually download the rss feed if it has changed
sub get_feed ($$) {
   my ($feed, $feedref) = @_;
   my $req = HTTP::Request->new(GET => $feedref->{$feed}{url});
   my $date = $feedref->{$feed}->{date} 
      if (exists $feedref->{$feed} and $feedref->{$feed}->{date});
   my $etag = $feedref->{$feed}->{etag} 
      if (exists $feedref->{$feed} and $feedref->{$feed}->{etag});
   $req->header('If-Modified-Since' => $date)  if ($date);
   $req->header('If-None-Match' => $etag) if ($etag);
   if ($feedref->{$feed}{credentials}) {
      my ($username, $password) = split /:/, $feedref->{$feed}{credentials};
      # $ua->get_basic_credentials = sub { return ($username, $password) };
   }
   my $res = $ua->request($req);
   unless ($res->is_success) {
      # if code == 304 that means the request worked, but there was
      # nothing new to get
      unless ($res->code == 304) {
         my $code = $res->code;
         my $message = $res->message;
         warn "Error retrieving $feed, $code - $message\n";
      } elsif ($debug) { print "\t - Not Changed\n"; }
      return "";
   }
   return $res;
}

# convert the http responce into a parsed rss object
sub get_rss ($$) {
   my ($feed, $res) = @_;
   my $rss = new XML::RSS;
   my $content = $res->content;
   $content =~ s/([\xC0-\xDF])([\x80-\xBF])/chr(ord($1)<<6&0xC0|ord($2)&0x3F)/eg;
   eval {$rss->parse($content);};
   if ($@) {
      warn "'$feed': $@\n";
      return "";
   }
   return $rss;
}

#extract all the good stuff for a specific rss item into an easily
#usable structure
sub flatten_item ($$) {
   my ($item, $rss) = @_;
   my %thisitem = ( rss => {}, 
                item => {}, 
                wiki => {}, 
                slash => {},
              );
   $thisitem{rss}{title} = $rss->channel('title');
   my $rss_webMaster = $rss->channel('webMaster');
   if ($rss_webMaster) {
      $thisitem{rss}{webMaster} = $rss_webMaster;
      $smtp{return} = $rss_webMaster;
   } else {
      $thisitem{rss}{webMaster} = "";
      $smtp{return} = $smtp{address} . "\@" . $smtp{host};
   }
   $thisitem{rss}{link} = $rss->channel('link');
   $thisitem{rss}{description} = $rss->channel('description');
   $thisitem{rss}{description} =~ s/\n//g;
   $thisitem{rss}{copyright} = $rss->channel('copyright');
   my $rss_pubdate = $rss->channel('pubDate');
   $thisitem{rss}{pubdate} = ($rss_pubdate) ? $rss_pubdate : "";
   $thisitem{item}{title} = (exists $item->{'title'}) ? $item->{'title'}: "";
   $thisitem{item}{link} = (exists $item->{'link'}) ? $item->{'link'} : "";
   $thisitem{item}{description} = (exists $item->{'description'}) ? $item->{'description'} : "";
   my $wiki = $item->{$rss->{namespaces}->{wiki}} if (exists $rss->{namespaces}->{wiki});
   $thisitem{wiki} = "" unless ($wiki);
   $thisitem{wiki}{diff} = $wiki->{diff} if (exists $wiki->{diff});
   $thisitem{wiki}{status} = $wiki->{status} if (exists $wiki->{status});
   $thisitem{wiki}{importance} = $wiki->{importance} if (exists $wiki->{importance});
   my $slash = $item->{$rss->{namespaces}->{slash}} if (exists $rss->{namespaces}->{slash});
   $thisitem{slash} = "" unless ($slash);

   return %thisitem;
}

# take an rss item and format the outgoing email message
sub build_message ($) {
   my $itemref = shift;
   my $message;
   my $hostname = `hostname -f`;
   chomp $hostname;
   $message .= "From: $itemref->{rss}{title}";
   $message .= ($itemref->{rss}{webMaster}) ? " <$itemref->{rss}{webMaster}>\n" : "\n";
   $message .= "Sender: " . $ENV{USERNAME} . "<" . $ENV{USER} . '@' . $hostname . ">\n";
   if ($itemref->{item}{title}) {
      $message .= "Subject: $itemref->{item}{title}\n";
   } else {
      $message .= "Subject: No item title\n";
   }
   $message .= "X-RSS-Name: $itemref->{feed}\n";
   $message .= "X-RSS-Link: $itemref->{rss}{link}\n" if ($itemref->{rss}{link});
   $message .= "X-RSS-Copyright: $itemref->{rss}{copyright}\n" if ($itemref->{rss}{copyright});
   $message .= "X-RSS-Description: $itemref->{rss}{description}\n" if ($itemref->{rss}{description});
   $message .= "X-URL: $itemref->{item}{link}\n";
   $message .= "X-STATUS: $itemref->{wiki}{status}\n" if ($itemref->{wiki} && $itemref->{wiki}{status});
   $message .= "X-IMPORTANCE: $itemref->{wiki}{importance}\n" if ($itemref->{wiki} && $itemref->{wiki}{importance});
   $message .= "X-DIFF: $itemref->{wiki}{diff}\n" if ($itemref->{wiki} && $itemref->{wiki}{diff});
   $message .= "X-SLASH: has slash data" if ($itemref->{slash});
   $message .= "\n";         # message body
   $message .= "\n";
   $message .= $itemref->{item}{description} if ($itemref->{item}{description});
   $message .= "\n";

   $message .= "---\n";      # add signature
   $message .= "$itemref->{rss}{title}\n";
   $message .= "$itemref->{rss}{link}\n" if ($itemref->{rss}{link});
   return $message;
}

# send an email message
sub send_message ($$$$) {
   my ($message, $smtpref, $feed, $feedref) = @_;
   $message = "To: $smtpref->{email}\n" . $message;
   my $digest = md5_hex($message);
   unless (exists $feedref->{$feed}{cache}{$digest}) {
      my $smtp = Net::SMTP->new($smtpref->{host}, Hello => 'localhost',);
      my $rc = $smtp->mail($smtpref->{return});
      my $to = $smtpref->{address} . "\@" . $smtpref->{host};
      $rc = $smtp->to($to);
      $rc = $smtp->data($message);
      $rc = $smtp->quit;
      return $digest;
   }
   return "";
}

# write all the etags and last-modified dates to the cache
sub write_cache ($$$) {
   my ($dir, $datafile, $feedref) = @_;
   open DATA, ">$dir/$datafile" or
      die "Can't write '$datafile', $!\n";
   foreach my $feed (keys %{$feedref}) {
      my $date = $feedref->{$feed}{date} || time;
      my $etag = $feedref->{$feed}{etag} || "";
      print DATA "$feed\t$date\t$etag\n";
   }
   close DATA;
}

# main loop for processing all of the feeds
sub process_feeds ($$) {
   my ($dir, $feedref) = @_;
   foreach my $feed (keys %{$feedref}) {
      if ($debug) {
         print "processing '$feed': ";
      }
      next unless ($feed);
      next if (load_msg_cache ($dir, $feed, $feedref));
      open CACHE, ">>$dir/$feed" or do {
         warn "Can't open '$dir/$feed' cache file, $!\n";
         next;
      };
      my $res = get_feed ($feed, $feedref);
      next unless ($res);

      my $etag = "\"" . $res->header('Etag') . "\"" if ($res->header('Etag'));
      $etag =~ s/^\"(.*)\"$/$1/g if ($etag);
      $feedref->{$feed}{date} = $res->last_modified;
      $feedref->{$feed}{etag} = $etag;

      my $rss = get_rss ($feed, $res);
      next unless ($rss);

      if ($debug) {
         print "\t", scalar @{$rss->items}, " items";
      }
      if ($debug) {
         $count = 0;
      }
      foreach my $item (@{$rss->items}) {
         my %item = flatten_item ($item, $rss);
         $item{feed} = $feed;
         my $message = build_message (\%item);
         my $digest = send_message ($message, \%smtp, $feed, $feedref);
         print CACHE $digest, "\n" if ($digest);
         if ($debug and $digest) {
            $count++;
         }
      }
      if ($debug) {
         print " $count new\n";
      }
      close CACHE;
   }
}

# read the ini file to get user prefs
sub parse($) {
   my $ini = shift;
   my @return;
   open INI, $ini or do {
      warn "Can't read '$ini', $!\n";
      return @return;
   };
   my @lines = <INI>;
   close INI;
   @return = grep {chomp; s/feeds\s*:\s*//} @lines;
   my $feedfile = shift @return;
   @return = grep {chomp; s/data\s*:\s*//} @lines;
   my $datafile = shift @return;
   @return = grep {chomp; s/email\s*:\s*//} @lines;
   my $email = shift @return;
   @return = grep {chomp; s/smtp\s*:\s*//} @lines;
   my $host = shift @return;
   @return = grep {chomp; s/addr\s*:\s*//} @lines;
   my $addr = shift @return;
   @return = grep {chomp; s/timeout\s*:\s*//} @lines;
   my $timeout = shift @return;
   @return = grep {chomp; s/proxy\s*:\s*//} @lines;
   my $proxy = shift @return;

   return ($feedfile, $datafile, $addr, $host, $email, $timeout, $proxy);
}

# run the main proceedure and exit it's return code
exit main_proc ($dir, $feedfile, $datafile, $daemon, $freq);
