#!/bin/bash

### Uncomment the DEBUG line to get debug logs ###
#DEBUG="TRUE"
REQUIRED_FILE="$1"

### BEGIN VAR SETUP ###
DATE=`which date`
ECHO=`which echo`
HOST=`which hostname`

CURL=`which curl`
OPENSSL=`which openssl`
RSYNC=`which rsync`
TAR=`which tar`
BINARIES=("curl" "openssl" "rsync" "tar")
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
        # The goal here is to create a bz2 file based on the provided file list as bz2 provides some of the best compression
        # and we pass the output of that bzipped2 data straight to openssl to create a salted, encrypted file based on
        # a provided password string
        RESULT=$(${TAR} -jvcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc")
    else
        RESULT=$(${TAR} -jcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc")
    fi
    ${ECHO} "$RESULT"
}

copy_backup() {
    if [ ! -z "$DEBUG" ]; then
        # Gotta love bash variable scoping, we can reuse the $name variable from the log function here
        RESULT=$(${CURL} -vvvv -SL -u $NEXTCLOUD_USER:$NEXTCLOUD_PASS -T ${LOCATION}backup.tar.enc "$NEXTCLOUD_URL/$name/")
    else
        RESULT=$(${CURL} -sL -u $NEXTCLOUD_USER:$NEXTCLOUD_PASS -T ${LOCATION}backup.tar.enc "$NEXTCLOUD_URL/$name/")
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
    log "DEBUG" "Argument #1: $REQUIRED_FILES"
    [ -z "$REQUIRED_FILE" ] && { log "ERROR" ".pass or .options file not specified but it is required! Cannot continue!"; exit 1004; }
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
    [ ! -z "$RESULT" ] && { log "ERROR" "Unable to complete backup! Consider enabling DEBUG logging..."; exit 1005; }
    log "INFO" "Backup complete!"

    log "INFO" "Copying backup to central server..."
    RESULT=$(copy_backup)
    log "DEBUG" "Result of copy_backup function: $RESULT"
    [ ! -z "$RESULT" ] && { log "ERROR" "Unable to complete copy! Consider enabling DEBUG logging..."; exit 1006; }
    log "INFO" "Copy complete!"
}
### END FUNCTIONS ###

### MAIN ###
begin
main
