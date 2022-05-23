#!/bin/bash

### Uncomment the DEBUG line to get debug logs ###
DEBUG="TRUE"
REQUIRED_FILE="$1"

### BEGIN VAR SETUP ###
DATE=`which date`
ECHO=`which echo`
HOST=`which hostname`

OPENSSL=`which openssl`
RSYNC=`which rsync`
TAR=`which tar`
BINARIES=("openssl" "rsync" "tar")
### END VAR SETUP ###

### BEGIN FUNCTIONS ###
log() {
    time=`${DATE}` || return 1
    name=`${HOST}` || return 1
    if [ ! -z "$DEBUG" ]; then
        if [ "$1" = "DEBUG" ]; then
            log_debug "$2"
            return 0
        fi
    else
        if [ "$1" = "DEBUG" ]; then
            return 1
        fi
    fi
    ${ECHO} "$time $name [$1] $2"
}

log_debug() {
    ${ECHO} "$time $name [DEBUG] $1"
}

root_check() {
    if [[ "$EUID" -ne 0 ]]; then
        log "ERROR" "Are you running as root?"
        exit 1001
    fi
}

check_file() {
    [ -f "$1" ] || { log "ERROR" "Cannot find $1! Cannot continue!"; exit 1001; }
}

check_folder() {
    [ -d "$1" ] || { log "ERROR" "Cannot find $1! Cannot continue!"; exit 1002; }
}

run_backup() {
    if [ ! -z "$DEBUG" ]; then
        RESULT=$(${TAR} -jvcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc")
    else
        RESULT=$(${TAR} -jcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc")
    fi
    ${ECHO} "$RESULT"
}

begin() {
    log "INFO" "Starting script..."

    log "INFO" "Starting root check..."
    log "DEBUG" "Comparing EUID: $EUID against 0..."
    root_check
    log "INFO" "Root check complete!"

    log "INFO" "Starting dependencies check..."
    for ((i=0; i < ${#BINARIES[@]}; i++)); do
        log "DEBUG" "Checking if ${BINARIES[i]} exists..."
        RESULT=$(which ${BINARIES[i]} > /dev/null 2>&1; echo $?)
        if [[ "$RESULT" = "1" ]]; then
            log "ERROR" "${BINARIES[i]} does not exist! Cannot continue!"
            exit 1003
        fi
        log "DEBUG" "Result of which check: $RESULT"
    done
    log "INFO" "Dependency check complete!"

    log "INFO" "Starting options file check..."
    check_file $REQUIRED_FILE
    source $REQUIRED_FILE
    log "INFO" "Options file check complete!"

    log "INFO" "Starting file list check..."
    check_file $FILES
    log "INFO" "File list check complete!"
}

main() {
    log "INFO" "Starting backup..."

    RESULT=$(run_backup)
    log "DEBUG" "Result of run_backup function: $RESULT"

    log "INFO" "Backup complete!"
}
### END FUNCTIONS ###

### MAIN ###
begin
main

# Bring in the password and file list from a read-only file
# Make sure file is only owned by the user doing the backups
# source .pass

# TAR=`which tar`
# OPENSSL=`which openssl`

# Create a bzip2 file based on the files in the list and pass the data to openssl and output as a .tar.enc file
# ${TAR} -jvcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > /tmp/backup.tar.enc