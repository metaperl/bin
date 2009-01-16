#!/usr/bin/perl

while (<STDIN>) {
  if ($_ =~ m{(\[\d\d:\d\d\]) <(\S+)> (.+)}) {
    $OUT .= "$1 [$2] $3\n";
  } else {
    $OUT .= "$_";
  }
}

print $OUT;
