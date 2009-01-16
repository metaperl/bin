my $ip;

my $line = `ipconfig | grep 'IP Address' `;
warn $line;
if ($line =~ /(\d+([.]\d+){3})/) {
  $ip = $1;
} else {
    print "NO MATCH";
}

my $display = "$ip:0.0";
warn $display;
`ssh schemelab\@li2-168.members.linode.com 'echo $display > /tmp/my_display'`;

