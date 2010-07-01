#!/usr/bin/perl



# {{{ use pragmas and modules

use strict;
use Text::Template;

# }}}


# {{{ Define $OUT, $file, $file_base, $file_tmp, $file_pm

our $OUT;
my $file        = shift or die 'file name not supplied';
my ($file_base) = ($file =~ /(.+)[.]\w+/) ;
my $file_tmp    = "$file_base.tmp";
my $file_pm     = "$file_base.pm";

# }}}

# {{{ Define pod_include(), the workhorse subroutine
sub pod_include {
    my ($file, $indent, $prepend) = @_;

    open F, $file or die $!;
    $OUT = $prepend;

    my $spaces = " " x $indent;

    while (<F>) {
	$OUT .= "$spaces$_";
    }
    $OUT;
}
# }}}

# {{{ Define present_file() which renders a filename as commented text
sub present_file {
  my $file = shift or die "must supply filename";
  return <<"EOFLAG";

 # 
 # $file
 #

EOFLAG
}
# }}}

# {{{ Define pod_code() a routine which leverages pod_include()
sub pod_code {
    my $file = shift or die "NO FILE SUPPLIED";
    my $show_filename = shift;
    my $file_presentation = present_file($file) if $show_filename;
    pod_include($file, 1, $file_presentation);
}
# }}}

# {{{ Create our Text::Template object
warn "Text::Template is generating $file_pm";
my $template = Text::Template->new
    (TYPE => 'FILE',  SOURCE => $file, DELIMITERS => [ '<tt>', '</tt>' ]);
# }}}

# {{{ Open $file_pm and output template contents to it
open  O, ">$file_tmp" or die $!;
print O $template->fill_in;
close(O);
# }}}

# {{{ Convert $file_pm to text and html variants

system 'pod2text', $file_tmp, "$file_base.txt";
system ('pod2html', "--infile=$file_pm", "--outfile=$file_base.html");

# }}}


