#!/usr/bin/perl

use Net::SCP qw(scp);

use strict;

my $emacs = "$ENV{HOME}/emacs";

my $dest = 'metaperl@urth.org:rsync/';

my @file = (
	    "$ENV{HOME}/.bashrc",
	   );
push @file, map { "$ENV{HOME}/chess/training.$_" } qw(si3 sn3 sg3) ;
	   
push @file, "$emacs/shell-current-directory.el";

scp ($_, $dest) for @file;


  
