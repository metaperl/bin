#!/usr/bin/perl

use strict;
use warnings;

my $process_name = shift or die 'process name?';
my $username     = 'tbrannon';

warn $process_name;

open WAXU, "ps waxu | egrep $process_name|";

my @pid;
while (<WAXU>) {

  my ($pid) = ($_ =~ /$username (\d+)/) ;
  push @pid, $pid if ($pid) ;

}

kill 9, @pid ;
