#!/bin/bash

### Uncomment the DEBUG line to get debug logs ###
#DEBUG="TRUE"
REQUIRED_FILE="$1"

### BEGIN VAR SETUP ###
ERROR=0
BACKUP_FILE="/tmp/.backup_complete"

DATE=`which date`
ECHO=`which echo`
HOST=`which hostname`
TEE=`which tee`

CURL=`which curl`
DIRNAME=`which dirname`
LS=`which ls`
PWD=`which pwd`
OPENSSL=`which openssl`
RSYNC=`which rsync`
TAR=`which tar`
BINARIES=("curl" "openssl" "rsync" "tar")

SCRIPT_DIR=$(${DIRNAME} -- "$0")
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
        if [ ! -z "$EXCLUDED_FILES" ]; then
            RESULT=$(${TAR} -jvcO -X $EXCLUDED_FILES -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc")
        else
            RESULT=$(${TAR} -jvcO -T $FILES | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc")
        fi
        log "DEBUG" "The result of run_backup() is: $RESULT"
    else
        if [ ! -z "$EXCLUDED_FILES" ]; then
            RESULT=$(${TAR} --warning=none -jcO -X $EXCLUDED_FILES -T $FILES 2>/dev/null | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc" 2>/dev/null)
        else
            RESULT=$(${TAR} --warning=none -jcO -T $FILES 2>/dev/null | ${OPENSSL} enc -aes-256-cbc -md sha256 -pass pass:$PASS > "${LOCATION}backup.tar.enc" 2>/dev/null)
        fi
    fi
    
    ${ECHO} $?
}

copy_backup() {
    if [ ! -z "$DEBUG" ]; then
        # Gotta love bash variable scoping, we can reuse the $name variable from the log function here
        RESULT=$(${CURL} -vvvv -SL -u $NEXTCLOUD_USER:$NEXTCLOUD_PASS -T ${LOCATION}backup.tar.enc "$NEXTCLOUD_URL/$name/")
        log "DEBUG" "The result of copy_backup() is: $RESULT"
    else
        RESULT=$(${CURL} -sL -u $NEXTCLOUD_USER:$NEXTCLOUD_PASS -T ${LOCATION}backup.tar.enc "$NEXTCLOUD_URL/$name/")
    fi
    ${ECHO} $?
}

pre_backup() {
    # -n = The length of STRING is greater than zero
    if [ -n "$(${LS} -A $SCRIPT_DIR/pre_scripts/ 2>/dev/null)" ]; then
        log "INFO" "Pre-backup script(s) found! Executing script(s)..."
        for i in `${LS} $SCRIPT_DIR/pre_scripts/`; do
            if [ ! -z "$DEBUG" ]; then
                /bin/bash "$SCRIPT_DIR/pre_scripts/$i" 2>/dev/null
            else
                /bin/bash "$SCRIPT_DIR/pre_scripts/$i"
            fi
            if [ "$?" != 0 ]; then
                log "ERROR" "$SCRIPT_DIR/pre_scripts/$i exited with $?! Consider enabling DEBUG logging..."
                exit 1007
            fi
        done
    fi
}

post_backup() {
    # -n = The length of STRING is greater than zero
    if [ -n "$(${LS} -A $SCRIPT_DIR/post_scripts/ 2>/dev/null)" ]; then
        log "INFO" "Post-backup script(s) found! Executing script(s)..."
        for i in `${LS} $SCRIPT_DIR/post_scripts/`; do
            if [ ! -z "$DEBUG" ]; then
                /bin/bash "$SCRIPT_DIR/post_scripts/$i" 2>/dev/null
            else
                /bin/bash "$SCRIPT_DIR/post_scripts/$i"
            fi
            if [ "$?" != 0 ]; then
                log "ERROR" "$SCRIPT_DIR/post_scripts/$i exited with $?! Consider enabling DEBUG logging..."
                exit 1008
            fi
        done
    fi
}

backup_complete() {
    ${ECHO} "done" | ${TEE} "$BACKUP_FILE"
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

    log "INFO" "Checking for any pre-backup scripts..."
    pre_backup
    log "INFO" "Pre-backup script(s) complete!"

    log "INFO" "Running backup..."
    RESULT=$(run_backup)
    if [ $RESULT != "0" ]; then
        log "ERROR" "Unable to complete backup! Consider enabling DEBUG logging..."
        log "DEBUG" "The run_backup() function failed with error code: $RESULT"
        ERROR="$RESULT"
        exit 1005
    fi
    log "INFO" "Backup complete!"

    log "INFO" "Copying backup to central server..."
    RESULT=$(copy_backup)
    if [ $RESULT != "0" ]; then
        log "ERROR" "Unable to complete copy! Consider enabling DEBUG logging..."
        log "DEBUG" "The copy_backup() function failed with error code: $RESULT"
        ERROR="$RESULT"
        exit 1006
    fi
    log "INFO" "Copy complete!"

    log "INFO" "Checking for any post-backup scripts..."
    post_backup
    log "INFO" "Post-backup script(s) complete!"

    if [ $ERROR = "0" ]; then
        backup_complete
    fi
}
### END FUNCTIONS ###

### MAIN ###
begin
main
