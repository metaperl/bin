$_ = 'Subject: Fwd: 630 Asciidoc-discuss moderator request(s) waiting';

use lib '.';
use myfilter;

warn moderator_request($_);
