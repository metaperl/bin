#!/usr/bin/perl
use strict;

my $largerthan = shift or die 'must supply larger than';

my @file;
while (<STDIN>) {

  my ($size, $file) = split;

  $size >= $largerthan and push @file, $file;

}

warn "@file";

my @system = ('tar', '--create', '--file', 'tar.tar', @file);
system @system;

