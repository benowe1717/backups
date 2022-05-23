#!/bin/bash

# Bring in the password and file list from a read-only file
# Make sure file is only owned by the user doing the backups
source .pass

TAR=`which tar`
OPENSSL=`which openssl`

# Create a bzip2 file based on the files in the list and pass the data to openssl and output as a .tar.enc file
${TAR} -jvcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > /tmp/backup.tar.enc