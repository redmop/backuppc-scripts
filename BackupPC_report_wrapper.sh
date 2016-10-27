#!/bin/bash

EMAIL_SUBJECT="BackupPC Report for $(date +'%m-%d-%Y')"

if $(/var/lib/backuppc/bin/BackupPC_report.pl | /bin/grep '*WARNING*\|*ERROR*' -q) ; then
        EMAIL_SUBJECT="--WARNINGS-- $EMAIL_SUBJECT"
#else
#       #no change
fi

/var/lib/backuppc/bin/BackupPC_report.pl | /usr/bin/mail -s "$EMAIL_SUBJECT" <email@example.com
