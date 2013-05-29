#!/usr/bin/perl

### /home/anthrax/Program/autoreply/autoreply.pl
### created: May 29,2013 Wednesday 14:05:41
### author: anthrax(KAWAHARA Masashi)
### $Id$

#  Last modified Wed May 29 17:35:09 2013 on joker
#  Update count: 10

use strict;
use Sys::Syslog qw(:DEFAULT setlogsock);

my $SELF = 'autoreply.pl';
my $SENDMAIL = '/usr/sbin/sendmail';
my $REPLYMSG_DIR = '/home/vmail/autoreply';
my $EX_OK = 0;
my $EX_TEMPFAIL = 75;
my $EX_UNAVAILABLE = 69;
my $sender = '';
my $mailbox = '';

setlogsock('unix');
openlog($SELF, 'ndelay,pid', 'mail');

if ( @ARGV != 2) {
    syslog('err', "error: Invalid invocation (expecting 2 argument)");
    exit($EX_TEMPFAIL);
} else {
    $sender = $ARGV[0];
    $mailbox = $ARGV[1];
}

if (! -x $SENDMAIL) {
    syslog('err', "error: $SENDMAIL not found or not executable");
    exit($EX_TEMPFAIL);
}

# don't answer special user
if ($sender eq "" || $sender =~ /^owner-|-(request|owner)\@|^(mailer-daemon|postmaster|vacation)\@/i) {
   exit($EX_OK);
}

# check Precedence header and loop-check
while ( <STDIN> ) {
    last if (/^$/);
    exit($EX_OK) if (/^precedence:\s+(bulk|list|junk)/i);
    exit($EX_OK) if (/^x-loop-check: /i);
}

my $autoreply_message_file = "$REPLYMSG_DIR/$mailbox";
if (! -f "$autoreply_message_file") {
    syslog('err', "error: not found $autoreply_message_file");
    exit($EX_TEMPFAIL);
}

# open autoreply message
my $messagefh;
if (! open $messagefh, '<', $autoreply_message_file) {
    syslog('err', "error: can't open $autoreply_message_file: %m");
    exit($EX_TEMPFAIL);
}
my @messages = <$messagefh>;

# send message
open my $mailfh, "| $SENDMAIL -t -r ''";
print $mailfh "To: $sender\n";
print $mailfh "X-Loop-Check: 1\n";
foreach my $line (@messages) {
    chomp($line);
    print $mailfh "$line\n";
}
if (! close $mailfh) {
    syslog('err', "error: failure invoking $SENDMAIL: %m");
    exit($EX_UNAVAILABLE);
}
close $messagefh;
syslog('info', "sent autoreply to $sender");
exit($EX_OK);
