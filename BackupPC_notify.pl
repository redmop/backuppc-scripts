#!/usr/bin/perl
#################
#
# BackupNotify : send mail after a good or a bad backup
# BackupNotify_success : send email only after a good backup
# BackupNotify_failure : send email only after a bad backup
#
# jmb 20/06/2006
# jmb 10/10/2007
#
# parameters : $user $xferOK $host $type $client $hostIP
#
use Socket;

$mailprog = '/usr/sbin/sendmail';

$user = $ARGV[0];
$xferOK = $ARGV[1];
$host = $ARGV[2];
$type = $ARGV[3];
$client = $ARGV[4];
$hostIP = $ARGV[5];

$recipient = $user;

$script = $0;
$success = 1;
$failure = 1;

if ($script =~ 'success.pl'){ $failure = 0; }
if ($script =~ 'failure.pl'){ $success = 0; }

#
# extract only errors from XferLOG
#
my $status=`/usr/share/backuppc/bin/analyse_backups $client`;
($xferErr,$badFile,$TopDir,$xferlognum) = split(/-/,$status);
chop($xferlognum);
$xferErr = int($xferErr);
$xferlognum = int($xferlognum);
my $list_error=`/usr/share/backuppc/bin/BackupPC_zcat /var/lib/backuppc/pc/$client/XferLOG.$xferlognum.z | grep DENIED | grep -v 'System Volume Information' | grep -v RECYCLER |grep -v Watson |grep -v squid`;

#
#
$msg = "BackupPC backup report for the PC \"$client ($hostIP)\" : \n\n";
if ( $xferOK) {
if ( length($list_error) > 0) {
$msg .= "The backup ($ type) has ALMOST smoothly ...\n\n";
$msg .= "Transfer errors occurred ...\n\n";
$msg .= "The following errors :\n";
$msg .= "$list_error\n";
$msg .= "This can occur in the following situations :\n";
$msg .= " - When a file is in use\n";
$msg .= " - When a folder / file access permissions too restrictive\n\n";
$msg .= "In any event, managers are warned ...\n";
$ccrecipient = "user@example.com";
$subject = "Backup for $client : ok BUT... !";
if ( $success ){ &sendmail($msg); };
} else {
$msg .= "The ($type) backup went well\n";
$ccrecipient = "";
$subject = "Backup for $client : OK !";
if ( $success ){ &sendmail($msg); };
}
} else {
$msg .= "The backup ($type) has a problem ! \n";
$subject = "Problem with backup $client...";
if ( $failure ) { &sendmail($msg); };
}

sub sendmail {
my($msg) = @ _;
open(MAIL, "|$mailprog -t") && do {
print MAIL "To: $recipient\n";
print MAIL "From: backuppc\@example\n";
print MAIL "Cc: $ccrecipient\n";
# print MAIL "Bcc:\n";
print MAIL "Subject: $subject \n\n";
print MAIL "$msg\n";
print MAIL "\nVisit the site regularly <https://backuppc/backuppc>\n";
print MAIL "\nContact support : mailto:user\@example.com\n";
close (MAIL);
};
}
