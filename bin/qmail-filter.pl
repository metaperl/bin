#!/usr/bin/perl

# Filter mail messages
# Based on several criteria.

# This is designed to be invoked from a .qmail file.
# That means:
#
# 1. If the message is accepted, forward to the $Forward{Accept} address,
#    exit 0.  (Continue processing of this qmail file.)
#
# 2. If the message is rejected, forward to the $Forward{Reject} address,
#    deliver rejection notice to sender, 
#    exit 0.  (Continue processing of this qmail file.)
#
# 3. If an error occurred, exit 111 (qmail should try again soon.)

#
# Rules for accept/reject:
#
# L. Is message from a loser?
# U. Is recipient actually this user?
# M. Is recipient a mailing list this user knows about?
# S. Is message from a bad site?
# G. Is message from a good person?
# J. Subject contains password `junkless'?
#
# If (L) reject;
# If (M) accept;   # To avoid annoying list owner.
# If (J) accept;   # If it has the password, just let it in.
# If (U) {         # Send to me
#   if (G) accept; # Always accept from good people
#   if (S) {       # Bad site, unknown person
#     markbad; reject; # Unknown person from suspect site; reject.
#   }
#   accept;        # Good site---default is accept.
# } else {         # not sent to me, unknown bulk list?
#   reject;
# }

$LOCAL = $ENV{LOCAL};
$USER = $ENV{USER};
$HOME = $ENV{HOME};

@ML = qw(weenie-whiners
	 junk-l
	 bizarchive
	 artichoke
	 fictionary
	 tb-moo-wizards
	 teebeedee
	 coincidence
	 );

@bad_words = qw(cyberpromo stealth iemmc i.e.m.m.c. extractor shopppingplanet
		floodgate
		);

@ok_domains = qw(plover.com op.net upenn.edu);

use Carp;
use Fcntl ':flock';

%ARGV = @ARGV;

$LOGFILE = $ARGV{LogFile} || '/tmp/qfilter';
unless ($) {
  open OLDSTDERR, ">&STDERR";
  open(STDERR, ">> $LOGFILE") or &defer("Couldn't open $LOGFILE: $!");
  print STDERR "\nStarting with pid $$ at time ", scalar(localtime()), "\n";
}
select undef, undef, undef, rand(3);
if (1) {
  &defer("Couldn't lock semaphore file ($!)") 
      unless flock STDERR, LOCK_EX;
} else {
  unless (flock STDERR, LOCK_EX | LOCK_NB) {
    &defer("Someone else is already running");  # temporary failure
    
    # Old code: retry several times and then defer
    my $n = 5;
    my $success = 0;
    while ($n) {
      my $ZZZZ = 2**(6-$n);
      my $s = $n == 1 ? '' : 's';
      warn "Couldn't lock semaphore file; retry $n more time$s in $ZZZZ seconds.\n";
      select undef, undef, undef, $ZZZZ - 1 + rand 2;
      last if $success = flock STDERR, LOCK_EX | LOCK_NB;
      $n--;
    }
    &defer("Couldn't lock semaphore file ($!)") unless $success;
  }
}

$SUBJLOG = $ARGV{SubjectLog} || '/tmp/qfsubjectlog';
$BLACKLOG = $ARGV{BlackLog} || '/tmp/qfblacklistlog';
$RECENT_SUBJECTS = $ARGV{RecentSubjects} || '/tmp/qfrecentsubjects';

$PASSWORD = 'yjunk';

{ my ($y, $m, $d) = (localtime)[5,4,3];
  $DATE = sprintf "%4d%02d%02d", $y+1900, $m+1, $d;
}

$BADSITE_FILE = "$HOME/lib/mail.badsites";
$MATCHLESS = "qjdhqhd1!&@^#^*&!@#"; # Should not match any bad site pattern

# to enable vacationing, don't turn it on here.
# change it in ~/.qmail-filter-deliver2
%Forward = (
#	    Accept => $ARGV{DeliveryAddress} || "$LOCAL-vacation",
	    Accept => $ARGV{DeliveryAddress} || "$LOCAL-deliver2",
	    Reject => $ARGV{RejectionAddress} || "$LOCAL-reject",
	    Error  => $ARGV{ErrorAddress} || "$LOCAL-error",
	    );

%Reject_File = ('loser' => "$HOME/lib/mail.loser",
		'badsite' => "$HOME/lib/mail.sorry",
		'bulklist' => "$HOME/lib/mail.bulklist",
		'multicast' => "$HOME/lib/mail.multicast",
		'content' => "$HOME/lib/mail.content",
		'badheader' => "$HOME/lib/mail.badheader",
		'cyberpromo' => "$HOME/lib/mail.stinkford",
		);

$DB = "$HOME/lib/mail.allow";
$DOMAIN = "$HOME/lib/mail.baddomain";
use DB_File;

until ($db = tie %db, DB_File, $DB) {
  if ($! =~ /Try again/) {
    print STDERR "Zzzz...\n";
    sleep 1;
  } else {
    &defer("Couldn't bind database in `$DB': $!");
  }
}
# until ($ddb = tie %ddb, GDBM_File, $DOMAIN, &GDBM_WRCREAT, 0666, \&gdbm_fatal) {
#   if ($! =~ /Try again/) {
#     print STDERR "Zzzz...\n";
#     sleep 5;
#   } else {
#     &defer("Couldn't bind database in `$DOMAIN': $!\n");
#   }
# }

$ME = "$LOCAL-discard\@plover.com";
# $ME = "";

################################################################
#
# A special mode (`scrub') for editing the database.
# It is up here because it does not require an input message.
#
################################################################


if ($ARGV{Mode} eq 'Scrub') {
  my $pat = $ARGV{Pat};
  my @del;
  local($|) = 1;
  while (($k, $v) = each %db) {
    next unless $k =~ /$pat/o;
    print "Scrub `$k (=> $v)? ";
    my $r = <STDIN>;
    if ($r =~ /^y/i) {
      push @del, $k;
    }
  }
  foreach $k (@del) {
    delete $db{$k};
  }
  exit 0;
}

################################################################
#
# Read in and deconstruct the mail message
#
################################################################


# Read in header
while (<STDIN>) {
  $MESSAGE .= $_;
  last if /^\s*$/;		# End of header
  $HEADER .= $_;
  chop;
  if (/^\s/) {
    $H{$h} .= $_;
  } else {
    ($h, $c) = /^([A-Za-z0-9-]*):(?:\s?(.*))?$/;
    unless (defined($h)) {
      my $badline = $_;
      $badline =~ tr/\n//d;
      if ($ARGV{Mode} eq 'Auto-Blacklist') {
        warn "Exiting because of malformed header line: ``$badline'' in message, rejecting.\n";
        exit 100;
      } else {
        &reject('badheader', "Malformed header line: ``$badline'' in message, rejecting.\n");
      }
    }
    if (exists $H{$h}) {
      $H{$h} .= "\0$c";
    } else {
      $H{$h} = $c;
    }
  }
}

# Read in body
while (<STDIN>) {
  $MESSAGE .= $_;
  $BODY .= $_;
}

warn "Subject: $H{Subject}\n";

################################################################
#
# Handle special modes.  
# For example, `mark' means to find the addresses in the message 
# and to enter them in the database with the appropriate marks---
# default is to mark them OK with the current time.
#
################################################################

if ($ARGV{Mode} eq 'Reject') {
  if (open (S, ">> $BLACKLOG")) {
    print S "$DATE *** Blacklisted domain `$domain' for user $LOCAL.\n";
    close S;
  } else {
    print STDERR "Couldn't append to blacklist log file `$BLACKLOG': $!.\n";
  }
  &reject('loser');
}

# Mark has a number of options.  generally, it means to 
# note some of the addresses in the database.  If there is an `Outgoing'
# parameter, the mail is assumed to be `outgoing' and all the recipient
# addresses, including `To' and `CC' addresses, are marked.
# If there is a `Mark' parameter, the value in the database is set to that 
# parameter; for example, if `Mark loser' is applied, the users are
# marked with `loser' in the database.  The defaut is to mark with 
# the current time-since-epoch.
#
# Mail is normally `accept'ed; Outgoing mail is not
#
# Losers are not allowed to use this function.  
#
if ($ARGV{Mode} eq 'Mark') {
  my $mark = $ARGV{Mark};
  if (!defined($mark) && &is_loser()) {
    # Losers don't get to use this.
    &reject('loser');
  }
  warn "Invoked in Mark mode.  Mark is ", (defined($mark) ? "`$mark'" : "the time"), ".\n";
  my @who = $ARGV{Outgoing} ? &recipients() : &senders();
  foreach $s (@who) {
    my $m = defined($mark) ? $mark : time;
    $db{lc $s} = $m;
    warn "Marked address `$s' with `$m'.\n"; 
  }
  record_recent_subject();
  &accept if $ENV{NEWSENDER} && !$ARGV{Outgoing};
  exit 0;
} 


if ($ARGV{Mode} eq 'Auto-Blacklist') {
  print STDERR "Invoked in auto-blacklist-mode for local user $LOCAL.\n";
  if ($LOCAL =~ /reject-reject-reject/) {
    print STDERR "Strange blacklisting loop; exiting.\n";
    exit 0;
  }
  my %ok;
  foreach $d (@ok_domains) {
    $ok{$d}=1;
  }
  foreach $s (&senders, &forwarders) {
    my ($user, $site) = $s =~ /(.*)@(.*)/;
    next if $site =~ /\.\./;  # 'mail8..com' was leading to 'com' being blacklisted
    $site =~ s/\s+$//;  # How does a domain have trailing white space?  I don't know.
    next unless $site;
    next if 2 > ($site =~ tr/.//);
    my @components =  split(/\./, $site);
    my $n_comp = ($components[-1] =~ /^(edu|com|net|org|gov)$/) ? 2 : 3;
    exit 0 unless $n_comp > 1;
    my $domain = lc(join '.', @components[-$n_comp .. -1]);
    $domain =~ s/^\.//;  # Reamove leading . if there is one.
    print STDERR "Sender `$s' is in domain `$domain'.\n";
    next if $ok{$domain};
    print STDERR "Blacklisting domain `$domain'.\n";
    open B, ">> $BADSITE_FILE"
	or &defer("Couldn't append to badsite pattern file `$BADSITE_FILE': $!.  Deferring...\n");
    print B "\\b\Q$domain\E\$\n";
    close B;
    if (open (S, ">> $BLACKLOG")) {
      print S "$DATE *** Blacklisted domain `$domain' for user $LOCAL.\n";
      close S;
    } else {
      print STDERR "Couldn't append to blacklist log file `$BLACKLOG': $!.\n";
    }
  }
#  &reject();    # Why bother?
  exit 0;
}

################################################################
#
# Main logic
#
################################################################

if (&is_virus) {  print STDERR "It's a virus.\n"; exit  }
&accept if &is_daemon();
&reject('loser') if &is_loser; # Losers don't get to try the password.
&accept if &is_mailing_list;
&accept if (&contains_password);
&accept if &is_good_sender;
&accept if has_good_subject();
&reject('badsite', undef, "$BAD_SITE matches /$BAD_PAT/") if &is_suspicious_site;
&reject('multicast') if &is_multicast;
&reject('badheader', undef, "Misc bad header: $badheader") 
  if $badheader = &misc_bad_header;
&reject('content') if &content_is_dubious;
# &reject('cyberpromo') if &cyberpromo;
&accept;

sub inject {
  my $from = shift;
  my $fromarg = defined($from) ? ($from eq '' ? '""' : "'-f$from'") : "";
#  warn "Injecting: from=.$from.; fromarg=.$fromarg.\n";
  unless (open(INJECT, "| /var/qmail/bin/qmail-inject $fromarg")) {
    &defer("Oh no!  Couldn't run qmail-inject: $! . Deferring...\n");
  }
}

sub accept {
  warn "Accepting.\n";
  &forward($Forward{Accept});
  print FORWARD $MESSAGE;
  close FORWARD;
  exit 0;
}

sub reject {
  my $reason = shift;
  my $subject = shift || "Your mail to $LOCAL was rejected.";
  my $details = shift;

  warn "Rejecting: Reason is `$reason'.\n";
  warn "Details: $details.\n" if defined $details;

  &forward($Forward{Reject});
  print FORWARD $MESSAGE;
  close FORWARD;

  my $recip = $H{'Reply-To'} || $H{'From'} || $ENV{SENDER};
  unless (defined $recip) {
    warn "No recipient address could be found!\n";
    exit 0;
  }

  &mark_bad(&senders());

  if (open (S, ">> $SUBJLOG")) {
    print S $DATE, ' ', $H{Subject}, "\n";
    close S;
  } else {
    print STDERR "Couldn't append to subject log file `$SUBJLOG': $!.\n";
  }

  my $replyfile = $Reject_File{$reason};
  unless($replyfile) {
    &defer("No reply file was defined for reason `$reason'.\n");
  }
  unless (open REPLY, "< $replyfile") {
    &defer("Couldn't open  reply file `$replyfile' for reason `$reason': $!\n");
  }

  if ($ARGV{NoReply} || $H{Precedence} =~ /^(bulk|junk)$/i
     || $recip =~ /^http:/) {
    print STDERR "Suppressing reply to `$recip'\n";
    exit 0;
  }

  &inject($ME);
  print STDERR "Injecting mail to `$recip'.\n";
  print INJECT <<EOM;
From: $USER\'s automatic filtering service <$ME>
To: $recip
Subject: $subject
X-Rejection-Type: $reason
Precedence: bulk

EOM
  while (<REPLY>) {
    s/(\$[a-zA-Z_]\w*)/$1/ee;
    print INJECT;
  }

  print INJECT "---- Begin returned message\n";
  print INJECT $HEADER, "\n";
  foreach $line (split(/^/, $BODY)) {
    $line =~ s/^/- / if $line =~ /^-/;
    print INJECT $line;
  }
  print INJECT "---- End returned message\n";

  close INJECT;

  exit 0;
}

sub defer {
  my $msg = shift;
  carp $msg;
  if (open (TMP, "> /tmp/MESSAGE")) {
    print TMP $MESSAGE;
  }
  print OLDSTDERR $MESSAGE, "\n";
  exit 111;
}

sub forward {
  my $fwaddr = shift;
  unless (open(FORWARD, "| /var/qmail/bin/forward $fwaddr")) {
    &defer("Couldn't run forward to forward to $fwaddr.\n");
  }
}

sub mark_bad {
  foreach $addr (@_) {
    $addr = lc $addr;
    # Don't mark 'em bad unless they're unmarked or 
    # already bad.
    next if defined($db{$addr}) && $db{$addr} !~ /^reject-/;
    $db{$addr} = "reject-" . time;
    warn "Marked address `$addr' as bad.\n";
  }
}

sub is_loser {
  foreach $s (&senders()) {
    if ($db{lc $s} eq 'loser') {
      if (open (S, ">> $SUBJLOG")) {
        print S "$DATE +++++ $s is a loser.\n";
        close S;
      } else {
        print STDERR "Couldn't append to subject log file `$SUBJLOG': $!.\n";
      }
      return 1;
    }
  }
  return 0;
}

sub is_mailing_list {

  return 0; # Suppress this feature a while/
            # See how your qmail solution works instead.
  # Qmail solution:  Subscribe mjd-foo to list foo.  This bypasses the filter.

  foreach $ml (@ML) {
    if ($H{To} =~ /$ml/ || $H{Cc}=~ /$ml/) {
      return 1;
    }
  }
  return 0;
}

sub senders {
  return @senders if @senders;
  my ($s, %s);
  foreach $s (normalize_addresses(@H{'Reply-To', 'From'}, @ENV{SENDER})) {
    $s{$s}=1;
  } 
  @senders = keys %s;
  warn "Senders list is:\n\t@senders\n";

  return @senders;
}

sub recipients {
  return @recipients if @recipients;
  my @s = ($H{To}, 
	   split(/,\s*/, $H{Cc}), 
	   split(/,\s*/, $H{cc}), 
	   split(/,\s*/, $H{Bcc}), 
	   split(/,\s*/, $H{bcc}), 
	   );
  my %s;
  foreach $s (normalize_addresses(@s)) {
    next unless $s;
    $s{lc $s} = 1;
  }
  @recipients = keys %s;
  warn "Recipients list is:\n\t@recipients\n";

  return @recipients;
}


  
sub forwarders {
  return @forwarders if @forwarders;

  # Check the `received' line for suspicious forwarders
  # Extract words that look like host names
  @forwarders = 
      grep { /[A-Za-z]/ } ($H{'Received'} =~ m/(?:[\w-]+\.)+[\w-]+/g);
  # But hosts that my mail really is forwarded through are
  # never considered suspicious.
  @forwarders = grep { !/(\bplover\.com|\bcis\.upenn\.edu|\bpobox\.com|\bop\.net)$/i } @forwarders;
  foreach $r (@forwarders) {
    $r{lc $r} = 1;
  }
  @forwarders = keys %r;
#  warn "Forwarders list is:\n\t@forwarders\n";
  return @forwarders;
}

sub is_good_sender {
  foreach $s (&senders()) {
    if ($db{lc $s} > 0) {
      print STDERR "Sender `$s' is good.\n";
      return 1;
    }
  }
  return 0;
}

sub is_suspicious_site {
  my @s = (&senders(), &forwarders(), @H{'Reply-to'});
  my @badsites;

  # If there's only one `to' address, add it to the list of addresses
  # we'll check.
  push @s, $H{To} if $H{To} !~ /\@.*\@/ && ! $db{lc $H{To}};
  print STDERR "Addresses to check for suspiciousness:\n\t@s\n";

  my ($su, $ss) = times;
  unless ($badsite_pat) {
    my %seen;
    unless (open (BAD, "< $BADSITE_FILE")) {
      &defer("Couldn't open badsite pattern file `$BADSITE_FILE': $!.\n");
    }
    @badsites = grep {! $seen{$_}++} <BAD>;
#    @badsites = <BAD>;
    chomp @badsites;
    close BAD;
    print STDERR "There are ", scalar(@badsites), " bad site patterns.\n";

    my $pats = 0;
    while (@badsites) {
      my $PATSIZE = 250;
      my @bad = splice(@badsites, 0, $PATSIZE);
      my $badsite_pat = '(' . join(')|(', @bad) . ')';
    
      if ($MATCHLESS =~ /$badsite_pat/i) {
	&defer("The bad site pattern matched `$MATCHLESS', so I assume it would match anything.  Deferring...\n");
      }
  
      foreach $s (@s) {
	next unless $s;
	if (@matches = $s =~ /$badsite_pat/) {
	  my $i;
	  for ($i = 0; $i < @matches; $i++) {
	    if (defined($matches[$i])) {
	      my $patno = $i + $PATSIZE * $pats;
	      warn "Sender $s matched bad site pattern #$patno: $bad[$i].\n";
		  $BAD_PAT = $bad[$i];
	      $BAD_SITE = $s;
	      last;
	    }
	  }
	  return 1;
	}
      }

      $pats++;
    }
  }
  my ($eu, $es) = times;
  my ($tu, $ts) = ($eu-$su, $es-$ss);
  print STDERR "Elapsed time: user $tu sys $ts\n";

  return 1 if $H{'Received'} =~ /CLOAKED/;
  return 0;
}

sub is_multicast {
  @numerics = grep { ! /[A-Za-z]/ } ($H{'Received'} =~ m/(?:\w+\.)+\w+/g);
  foreach $s (@numerics) {
    # Only check items that look like IP addresses
    next unless $s =~ /^(\d{1,3})\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
    if (($1 & 0xE0) == 0xE0	# Class D or class E address?
	|| $1 == 0) {		# Zero's no good.
      $BAD_ADDR = $s;
      return 1;
    } 
    my @octets = ($s =~ /\d+/g);
    foreach $o (@octets) {
      if ($o > 255) {
	$BAD_ADDR = $s;
	return 1;
      }
    }
  }
  return 0;
}


sub misc_bad_header {
  return 'X-PMFLAGS header' if exists $H{'X-PMFLAGS'};
  return 'X-Advertisement header' if exists $H{'X-Advertisement'};
  return 'Fake Message-ID:' if $H{'Message-ID'} =~ /^\s*<\s*>\s*$/;
  return 'Rotten Message-ID:' if $H{'Message-ID'} =~ /\@.*\.\./ ;
  return 'Mangled time zone' if $H{Received} =~ /-0600 \(EST\)/
           || $H{Received} =~ /-0[57]00 \(EDT\)/;
  return 'Received: contains \'$domain\'' if $H{Received} =~ /\$domain/;
  return 'Addressed To: "you" or "friend"'  if $H{To} =~ /\b(you|friend)\b/i;
  return 'Message was handled by bulk.mail' 
    if $H{Received} =~ /bulk.mail/i 
      && $H{Received} !~ /ctrl-alt-del/ ;
  return 'Subject contains "ad"/"adv"' if $H{Subject} =~ /\badv?\b/i;
  return 'Subject: line contains $$$ ' if $H{Subject} =~ /\${3}/;
  return 'Subject: line contains HGH' if $H{Subject} =~ /\bHGH\b/;
  return 'Username is all digits' if $H{From} =~ /^\d+\@/;
  return 'From: line is <>' if $H{From} =~ /<>/;
  return 'From: line is <_@_>' if $H{From} =~ /<_\@_>/;
  return 'From: line is blank' if $H{From} eq '';
  return 'Missing From: line' unless exists $H{From};
  return 'no From: line' if $H{From} eq '';
  return 'no To: line' if $H{To} eq '';
  return 'Don\'t reply to spam mail!' if $H{Subject} =~ /help darren/i;
  return 'Recipient list too long' 
    if length($H{To}) + length($H{Cc}) > 1500;
  # I've tried checking for all-caps subject twice, and it sucked both times.
#   {				# Check for all-uppercase
#     my $s = $H{Subject};
#     $s =~ tr/A-Za-z//cd; 
#     # subject contains no lowercase letters
#     return 'Subject: all capitals' if $s !~ /[a-z]/  
#       && length($s) > 6;	# and at least six capitals
#   }
  return 'Korean ad (kwanggo)' 
      if $H{Subject} =~ /\xb1\xa4(\s*|(?:[\x80-\xff]{2})*)\xb0\xed/;
  return 'Chinese Language' if $H{Subject} =~ /^=\?(GB2312|big5)\?/;
  my $pat = join '|', @bad_words;
  foreach $h (keys %H) {
    next unless $h =~ /^X-/;
    return "Header `$h' contains bad word $1" if $H{$h} =~ /($pat)/io;
  }
  my $mailer = $H{'X-Mailer'};
  return "X-Mailer: contains $1" 
    if $mailer =~ /(shoppingplanet|extractor pro|marketing|platinum)/i;

  return 0;
}

sub contains_password {
  return $H{Subject} =~ /$PASSWORD/o;
}

sub is_daemon {
  return $H{From} =~ /(uucp|.*daemon|postmaster|abuse)\@/i;
}

sub cyberpromo {
  print STDERR "Cyberpromo checking...\n";
  my @senders = &senders();
  my $w;
  my $cp = 0;
  my $a;

  foreach $a (@senders) {
    my $s = $a;
    $s =~ s/.*\@//;
    my @s = split(/\./, $s);
    my $d = "\L$s[-2].$s[-1]";
    my $c = $ddb{$d} ;
    next if $c eq 'good';
    if ($c eq '') {
      print STDERR "Checking domain $d...\n";
      $c = 'good';
      open (WHOIS, "/usr/bin/whois $d|") or &defer;
      while (defined($w = <WHOIS>)) {
	if ($w =~ /cyberpromo/i) {
	  $db{$a} = "reject-cyberpromo-" . time;
	  $c = $ddb{$d} = 'bad';
	  last;
	}
      }
      print STDERR "Result: Domain $d is $c.\n";
    }

    if ($c eq 'bad') {
      print STDERR "Sender `$a' in bad domain `$d'.";
      $db{$a} = "reject-cyberpromo-" . time;
      $cp++;
    }

  }
  return $cp;
}

sub content_is_dubious {
  
}

# Ald address normalization code
sub na {
  my @s = @_;
  my $s;
  foreach $s (@s) {
    next unless $s;
    my $ns = lc $s;
    if ($ns =~ /\<(.*?)\>/) {
      $ns = $1;
    } elsif ($ns =~ /(.*?)\s*\(.*\)/) {
      $ns = $1;
    }

    $s{$ns} = 1;
  }
}

sub normalize_addresses {
  my @a = map {split /,\s+/, $_ } @_;
  my @r;
  local($_);
  foreach (@a) {
    next unless defined $_;
    if (/\<([^>]*)>/ || /(.*)\s+\([^\)]*\)/) {
      print STDERR "`$_' normalized to `$1'.\n";
      push @r, $1;
    } else {
      push @r, $_;
    }
  }
#  warn "Normalized addresses to: @a\n";
  @r;
}

sub record_recent_subject {
  my $rs = normalized_subject();
  my %s;
  unless (tie %s => 'DB_File', $RECENT_SUBJECTS, O_RDWR|O_CREAT, 0666) {
    warn "Couldn't tie recent subject database $RECENT_SUBJECTS: $!; continuing";
    return;
  } 

  $s{$rs} = time;
  untie %s;
}

sub has_good_subject {
  my %s;
  my $s = normalized_subject();
  warn "Checking to see if subject '$s' is good...\n";
  unless (tie %s => 'DB_File', $RECENT_SUBJECTS, O_RDONLY, 0666) {
    warn "Couldn't tie recent subject database $RECENT_SUBJECTS: $!; continuing";
    return;
  } 

  return if $s eq '';           # Null subject is never good.

  if ($s{$s}) {
    my $lastuse = localtime($s{$s});
    warn "That subject was seen as recently as $lastuse.\n";
    return 1;
  }
  untie %s;
  return;
}

sub normalized_subject {
  my $s = lc $H{Subject};
  $s =~ s/^\s*re:?\s*//;
  $s =~ s/^\s+//;
  $s =~ s/\s+$//;
  $s =~ tr/ \t/ /s;
  $s;
}

sub is_virus {
  $BODY =~ m|^TVqQAAMAAAAEAAAA//8AALgAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA$|m;
}

