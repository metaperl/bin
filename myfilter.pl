#!/usr/bin/perl -w

use strict;
use warnings;

use lib '/home/terry/install/share/perl';
use Mail::Procmail;


my $HOME = '/home/terry';
my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

# The default mailbox for delivery.
my $local     = inbox('deliv');
my $gmail     = 'metaperl@gmail.com';

# A pattern to break out words in email names.
my $wordpat = qr/[-a-zA-Z0-9_.]+/;
my $wordpat_nodot = qr/[-a-zA-Z0-9_]+/;

# subs
sub maildir { sprintf '/home/%s/Maildir', getpwuid($>) }
sub inbox   { sprintf '%s/INBOX.%s', maildir, $_[0] }

# Destination for mailing lists.
sub maillist { inbox "maillists.$_[0]" }

# Destination for SPAM.
sub spambox  { inbox "Spam.$_[0]" }

# Destination for JUNK
sub junkbox  { inbox "Junk.$_[0]" }



################ The Process ################

eval { ################ BEGIN PROTECTED EXECUTION ################

# Setup Procmail module.
my $m_obj = pm_init
    (
     logfile => "$HOME/bin/procmail/myfilter.log", loglevel => 3
    );

# Init local values for often used headers.
my $m_from		    = pm_gethdr("from");
my $m_to		    = pm_gethdr("to");
my $m_cc		    = pm_gethdr("getoptcc");
my $m_subject		    = pm_gethdr("subject");
my $m_sender		    = pm_gethdr("sender");
my $m_apparently_to	    = pm_gethdr("apparently-to");
my $m_resent_to		    = pm_gethdr("resent-to");
my $m_resent_cc		    = pm_gethdr("resent-cc");
my $m_resent_from	    = pm_gethdr("resent-from");
my $m_resent_sender	    = pm_gethdr("resent-sender");
my $m_apparently_resent_to  = pm_gethdr("apparently-resent-to");
my $m_spam_flag             = pm_gethdr('X-Spam-Flag') ;
my ($m_spam_status)         = (pm_gethdr('X-Spam-Status') =~ /score=(\S+)/ ) ;




my $m_header                = $m_obj->head->as_string || '';
my $m_lines		    = pm_body();
my $m_body                  = join("", @$m_lines);
my $m_size		    = length($m_body);

# These mimic procmail's TO and FROM patterns.
my $m_TO   = join("\n", $m_to, $m_cc, $m_apparently_to,
	                $m_resent_to, $m_resent_cc,
                        $m_apparently_resent_to);
my $m_FROM = join("\n", $m_from, $m_sender,
		        $m_resent_from, $m_resent_sender);

# Start logging.
pm_log(1, "Mail from $m_from");
pm_log(1, "To: $m_to");
pm_log(1, "Subject: $m_subject");
pm_log(1, "Header: $m_header");

################ Get rid of some #############

pm_reject("Non-plaintext-ASCII in subject")
  if $m_subject =~ /[\232-\355]{3}/;

pm_reject("Non-plaintext-ASCII in subject") if $m_spam_flag;



################ Intercepting ################


# It's probably a real message for me.
pm_resend($gmail);

}; ################ END PROTECTED EXECUTION ################

if ( $@ ) {
    # Something went seriously wrong...
    my $msg = $@;
    $msg =~ s/\n.*//s;

    # Log it using syslog.
    my ($tool, $facility, $level) = qw(procmail mail crit);
    require Sys::Syslog;
    import Sys::Syslog;
    openlog($tool, "pid,nowait", $facility);
    syslog($level, "%s", $msg);
    closelog();

    # Also, log normally.
    pm_log(0, "FATAL: $msg");

    # Turn it into temporary failure and hope someone notices...
    exit Mail::Procmail::TEMPFAIL;
}

################ Subroutines ################

sub spam {
    my ($tag, $reason, %atts) = ("spam", @_);
    my $line = (caller(1))[2];
    pm_log(2, $tag."[$line]: $reason");
    pm_deliver(spambox($tag), %atts);
}
