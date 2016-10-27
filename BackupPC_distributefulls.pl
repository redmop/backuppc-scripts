#!/usr/bin/perl

# BackupPC_distributefulls
# Distribute full dumps of multiple clients across many days in order to
# keep the duration of the nightly BackupPC run (aka your backup
# window) manageable.

# AUTHOR
#   Stephen Joyce <stephen@physics.unc.edu>
#
# COPYRIGHT
#   Copyright (C) 2008 Stephen Joyce
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#========================================================================
# Version 0.1, released 26 June, 2008
#========================================================================

# How to use
# 1. Save this file as /path/to/BackupPC/bin/BackupPC_distributefulls and
#    make it executable.
# 2. Call this file from cron periodically. It will do $daily_count fulls
#    manually each time it's launched. Doing this has the result of
#    distributing full dumps across multiple days (so your BackupPC server
#    doesn't getbogged down doing a full of ALL hosts every $FullPeriod days.
#    Distributing fulls like this keeps the backup window small.
#
# Under normal circumstances, you would run this from cron daily beginning 
# after a large number of hosts are added to your BackupPC server. Once all
# hosts are processed, the job may be cancelled until the next time it's
# needed. A crontab file for Linux might be called
# /etc/cron.d/BackupPC_distributefulls and look similar to this. (Remove ##
# from each line and change /path/to/BackupPC to the installed location of
# yourBackupPC installation). See the cron man pages for information on
# cron scheduling.
#
## # /etc/cron.d/BackupPC_distributefulls
## #
## # Stagger fulls of BackupPC hosts across multiple days
## #
##SHELL=/bin/sh
##
##0 12 * * * backup /path/to/BackupPC/bin/BackupPC_distributefulls
##
## # end /etc/cron.d/BackupPC_distributefulls


# variables that you should verify/modify
$DEBUG=0;          # Print debugging information.
$QUIET=0;          # Be very quiet. Generate no output unless an error occurs.
$daily_count=2;    # Number of fulls to run each time this script is launched.
$count_failures=0; # Change to 1 if you only want $daily_count attempts
                   # each day regardless of success or failure (instead of
		   # making attempts until $daily_count dumps are successful).

# other variables you probably won't have to modify
$BPCETC="/etc/BackupPC";
$CONFIG="$BPCETC/config.pl";
$HOSTSFILE="$BPCETC/hosts";
$STATEFILE="$BPCETC/distribute-state.txt"; # Where we save our list of processed hosts

#figure out where BackupPC is installed
open CONFIG,"<$CONFIG" or die "Can't open BackupPC config file for reading\n";
while (<CONFIG>) {
  chomp;
  my $line=$_;
  next if ! ($line=~/\$Conf{InstallDir}/);
  # form is $Conf{InstallDir} = '/path/to/BackupPC';
  $InstallDir=(split(/'/,$line))[1];
}
close(CONFIG);
$command="$InstallDir/bin/BackupPC_dump";
if ( -f "$command" ) {
  print "Found BackupPC installation at $InstallDir\n" if $DEBUG;
} else {
  die "Cound not find BackupPC at $InstallDir. Check BackupPC configuration.\n";
}

# Read the BackupPC hosts file.
# Construct a list of all hosts BackupPC knows about.
$validhostfile=0;
open HOSTS,"<$HOSTSFILE" or die "Can't open BackupPC hosts file for reading";
while (<HOSTS>) {
  chomp;
  my $line=$_;
  next if ($line=~/^#/);
  next if ($line=~/^\s+$/);
  #print "\"$line\"\n";
  if ($line=~/host\s*dhcp\s*user\s*moreUsers/) {
    $validhostfile=1;
    print "$HOSTSFILE is a valid hostfile.\n" if $DEBUG;
    next;
  }
  $myhost=(split(/\s+/,$line))[0];
  next if (! $myhost);
  print "Adding host $myhost\n" if $DEBUG;
  push (@hosts,$myhost);
  next;
}
close (HOSTS);
die "$HOSTSFILE doesn't appear to be a valid BackupPC hosts file" if ( ! $validhostfile );
print "\n" if $DEBUG;

if ( ! -f $STATEFILE) {
  print "No state file found. Creating..." if ( ! $QUIET );
  open STATE,">$STATEFILE";
  print STATE "distribute statefile\n";
  print STATE "# This file tracks hosts we've already processed.\n";
  print STATE "# Deleting a host from this file will cause it to be\n";
  print STATE "# processed the next time BackupPC_distributefulls is launched\n";
  print STATE "# (subject to the normal \$daily_count semantics.)\n";
  print " done\n" if ( ! $QUIET );
}

# Read state file
$validstatefile=0;
open STATE,"<$STATEFILE" or die "Can't open state file $STATEFILE file for reading";
while (<STATE>) {
  chomp;
  my $line=$_;
  next if ($line=~/^#/);
  next if ($line=~/^\s+$/);
  #print "\"$line\"\n";
  if ($line=~/distribute statefile/) {
    $validstatefile=1;
    print "$STATEFILE is a valid statefile.\n" if $DEBUG;
    print "To re-process a given host, remove its name from $STATEFILE\n" if $DEBUG;
    next;
  }
  $myhost=$line;
  next if (! $myhost);
  push (@donehosts,$myhost);
  next;
}
close (STATE);
die "$STATEFILE doesn't appear to be a valid state file" if ( ! $validstatefile );

# Do the work
open STATE,">>$STATEFILE" or die "Can't open state file $STATEFILE file for writing";
$counter=0;
for $host (@hosts) {
  next if ($counter >= $daily_count);
  my $processed=0;
  for $phost (@donehosts) {
    $processed=1 if ($phost eq $host);
  }
  if ($processed ) {
    print "Skipping $host. Previously processed.\n" if $DEBUG;
    next;
  }
  print "=======\n" if $DEBUG;
  print "Attempting a full backup of $host... " if ( ! $QUIET );
  print "\nRunning command $command -f $host\n" if $DEBUG;
  system ("$command -f $host");
  if ($? != 0 ) {
    # some error occurred. Ack!
    my $exit_value = $? >> 8;
    print "FAILED\n$command reported an error. Examine logs and verify desired result.\n";
    print "Exit value was ".$exit_value."\n";
    print "Not saving this host in state file. Will now attempt next host.\n\n";
    $counter++ if $count_failures;
  } else {
    print STATE "$host\n";
    $counter++;
    print "Command completed without error. Excellent!\n" if ( ! $QUIET );
  }
  print "=======\n" if $DEBUG;
}
close(STATE);
if ($counter == 0) {
  print " No hosts were processed. Either all commands exited with errors\n or all hosts have been previously processed.\n\n In either case, you should take action before the next time this\n script launches.\n";
}
