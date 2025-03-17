#!/bin/bash

#######################
### BEGIN CONSTANTS ###
#######################
BINARIES=("curl" "date" "dirname" "echo" "gpg" "hostname" "openssl" "rm" "tar")
DEBUG=0
OPTIONS=("BACKUP_DONE" "BACKUP_FOLDER" "FILES" "NEXTCLOUD_PASSWORD" "NEXTCLOUD_URL" "NEXTCLOUD_USERNAME" "PASSPHRASE")

CURL=$(which curl)
DATE=$(which date)
DIRNAME=$(which dirname)
ECHO=$(which echo)
GPG=$(which gpg)
HOSTNAME=$(which hostname)
OPENSSL=$(which openssl)
RM=$(which rm)
TAR=$(which tar)
#####################
### END CONSTANTS ###
#####################

##################
### BEGIN VARS ###
##################
error=0 # will be set to 1 if any error occurs during backup or transfer offsite
options="$1" # a required argument

# The next variables all come from the options file
my_files=""
my_exclusions=""
passphrase=""
nextcloud_user=""
nextcloud_password=""
nextcloud_url=""
backup_folder=""
backup_done=""
################
### END VARS ###
################

#######################
### BEGIN FUNCTIONS ###
#######################
check_binaries() {
    # Ensure all required binaries are present or exit
    for ((i=0; i < ${#BINARIES[@]}; i++)); do
        if ! which "${BINARIES[i]}" >> /dev/null 2>&1; then
            /bin/echo "${BINARIES[i]} cannot be found in $PATH"
            exit 1
        fi
    done
}

check_file() {
    if [ -f "$1" ] || [ -e "$1" ] || [ -L "$1" ]; then
        ${ECHO} 0
        return 0
    fi
    ${ECHO} 1
}

check_folder() {
    if [ -d "$1" ]; then
        ${ECHO} 0
        return 0
    fi
    ${ECHO} 1
}

check_variable_length() {
    if [ -n "$1" ]; then
        ${ECHO} 0
        return 0
    fi
    ${ECHO} 1
}

log() {
    local time # the current date and timestamp
    local name # the machine's hostname
    local print # 0 or 1, will control if a message is logged
    local level # the type of log level: ERROR, WARN, INFO, DEBUG
    local msg # the message to print

    time=$(${DATE} +"%b %d %T")
    name=$(${HOSTNAME})
    print=0
    level="$1"
    msg="$2"

    # If DEBUG is set to 1, print all messages
    # Else only print ERROR, WARN, and INFO messages
    if [[ "$DEBUG" -eq 1 ]]; then
        print=1
    else
        if [[ "$level" != "DEBUG" ]]; then
            print=1
        fi
    fi

    if [[ "$print" -eq 1 ]]; then
        ${ECHO} "$time $name [$level] $msg"
    fi
}

root_check() {
    if [[ "$EUID" -ne 0 ]]; then
        ${ECHO} 1
        return 1
    fi
    ${ECHO} 0
    return 0
}

argument_check() {
    if [ -z "$options" ]; then
        ${ECHO} 1
        return 1
    fi
    ${ECHO} 0
}

get_script_dir() {
    local dir
    dir=$(${DIRNAME} -- "$0")
    ${ECHO} "$dir"
}

get_files_in_dir() {
    local -a files=()
    for file in "$1"/*; do
        # Only progress to the next line if $file is a file and that file
        # exists or a symlink to a file exists
        [ -f "$file" ] || [ -e "$file" ] || [ -L "$file" ] || continue

        # Now check if the file is a shell script based on its file extension
        [[ "$file" =~ .sh$ ]] || continue

        # Finally, append to the array if all checks passed
        files+=("$file")
    done
    ${ECHO} "${files[@]}"
}

remove_file() {
    local file="$1"
    if ! ${RM} "$file"; then
        ${ECHO} 1
        return 1
    fi
    ${ECHO} 0
}

check_files_variable() {
    local result
    result=$(check_variable_length "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 1
        return 1
    fi
    result=$(check_file "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 2
        return 1
    fi
    ${ECHO} 0
}

check_backup_folder_variable() {
    local result
    result=$(check_variable_length "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 1
        return 1
    fi
    result=$(check_folder "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 2
        return 1
    fi
    ${ECHO} 0
}

check_passphrase_variable() {
    local result
    result=$(check_variable_length "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 1
        return 1
    fi
    result=$(check_file "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 2
        return 1
    fi
    ${ECHO} 0
}

check_nextcloud_url_variable() {
    local regex
    local result
    regex='^(https?)://[-_.[:alnum:]]*'

    result=$(check_variable_length "$1")
    if [[ "$result" -ne 0 ]]; then
        ${ECHO} 1
        return 1
    fi
    if [[ "$1" =~ $regex ]]; then
        ${ECHO} 0
        return 0
    fi
    ${ECHO} 2
}

pre_backup() {
    local cwd
    local folder
    local len
    declare -a files=()

    cwd=$(get_script_dir)
    folder="$cwd/pre_scripts"
    files=$(get_files_in_dir "$folder")
    len=${#files[@]}

    if [[ "$len" -eq 0 ]]; then
        log "DEBUG" "(pre_backup) No pre-backup scripts to run!"
        return 0
    fi

    log "DEBUG" "(pre_backup) Found $len pre-backup scripts to run..."
    for file in "${files[@]}"; do
        log "DEBUG" "(pre_backup) Running $file..."
        if ! /bin/bash "$file"; then
            log "ERROR" "(pre_backup) $file exited with $?! Consider enabling DEBUG logging..."
            exit 1
        fi
        log "DEBUG" "(pre_backup) $file finished running!"
    done
}

post_backup() {
    local cwd
    local folder
    local len
    declare -a files=()

    cwd=$(get_script_dir)
    folder="$cwd/post_scripts"
    files=$(get_files_in_dir "$folder")
    len=${#files[@]}

    if [[ "$len" -eq 0 ]]; then
        log "DEBUG" "(post_backup) No post-backup scripts to run!"
        return 0
    fi

    log "DEBUG" "(post_backup) Found $len post-backup scripts to run..."
    for file in "${files[@]}"; do
        log "DEBUG" "(post_backup) Running $file..."
        if ! /bin/bash "$file"; then
            log "ERROR" "(post_backup) $file exited with $?! Consider enabling DEBUG logging..."
            exit 1
        fi
        log "DEBUG" "(post_backup) $file finished running!"
    done
}

compress_files() {
    local args
    local output
    output="$1"

    if [[ "$DEBUG" -eq 1 ]]; then
        args="-jvcf $output"
    else
        args="-jcf $output"
    fi

    if [[ -n "$my_exclusions" ]]; then
        args="${args} --exclude-from=$my_exclusions --files-from=$my_files"
    else
        args="${args} --files-from=$my_files"
    fi

    log "DEBUG" "(compress_files) Executing $TAR $args"
    if ! ${TAR} ${args}; then
        log "ERROR" "(compress_files) Unable to compress files!"
        exit 1
    fi
    log "DEBUG" "(compress_files) Execution finished!"
}

encrypt_file() {
    local args
    local input
    local output
    local pass
    local redacted
    input="$1"
    output="$2"
    pass="$3"

    args="enc -aes-256-cbc -md sha512 -pbkdf2 -pass pass:$pass -in $input -out $output"
    redacted="enc -aes-256-cbc -md sha512 -pbkdf2 -pass pass:[REDACTED] -in $input -out $output"

    log "DEBUG" "(encrypt_file) Executing $OPENSSL $redacted"
    if ! ${OPENSSL} ${args}; then
        log "ERROR" "(encrypt_file) Unable to encrypt $input!"
        exit 1
    fi
    log "DEBUG" "(encrypt_file) Execution finished!"
}

encrypt_file_gpg() {
    local args
    local input
    local output
    local pass
    local redacted
    input="$1"
    output="$2"
    pass="$3"

    args="--batch --output $output --symmetric --cipher-algo AES256 --no-symkey-cache --passphrase-file $pass $input"
    redacted="--batch --output $output --symmetric --cipher-algo AES256 --no-symkey-cache --passphrase-file [REDACTED] $input"

    log "DEBUG" "(encrypt_file_gpg) Executing $GPG $redacted"
    if ! ${GPG} ${args}; then
        log "ERROR" "(encrypt_file_gpg) Unable to encrypt $input!"
        exit 1
    fi
    log "DEBUG" "(encrypt_file_gpg) Execution finished!"
}

copy_backup() {
    local args
    local file
    local name
    local redacted
    file="$1"
    name=$(${HOSTNAME})

    if [[ "$DEBUG" -eq 1 ]]; then
        args="-vvvv -SL"
    else
        args="-sL"
    fi
    args="${args} -u $nextcloud_user:$nextcloud_pass -T $file $nextcloud_url/$name/"
    redacted="${args} -u [REDACTED]:[REDACTED] -T $file $nextcloud_url/$name/"

    log "DEBUG" "(copy_backup) Executing $CURL $redacted"
    if ! ${CURL} ${args}; then
        log "ERROR" "(copy_backup) Unable to copy backup to Nextcloud!"
        exit 1
    fi
    log "DEBUG" "(copy_backup) Execution finished!"
}

backup_complete() {
    local file
    file="$1"
    ${ECHO} "done" > "$file"
}
#####################
### END FUNCTIONS ###
#####################

##################
### BEGIN FLOW ###
##################
required_options() {
    local error
    local options
    local result
    options="$1"
    source "$options"

    for ((i=0; i < ${#OPTIONS[@]}; i++)); do
        if [ ! -v "${OPTIONS[i]}" ]; then
            log "ERROR" "Problem detected with ${OPTIONS[i]}! Please double-check your config file!"
            error=1
        fi
    done

    result=$(check_files_variable "$FILES")
    if [[ "$result" -eq 1 ]]; then
        log "ERROR" "FILES option is unset!"
        error=1
    elif [[ "$result" -eq 2 ]]; then
        log "ERROR" "Unable to locate $FILES file!"
        error=1
    fi

    if [ -v "$EXCLUSIONS" ]; then
        result=$(check_files_variable "$EXCLUSIONS")
        if [[ "$result" -eq 1 ]]; then
            log "ERROR" "EXCLUSIONS option is enabled but unset!"
            error=1
        elif [[ "$result" -eq 2 ]]; then
            log "ERROR" "Unable to locate $EXCLUSIONS file!"
            error=1
        elif [[ "$result" -eq 0 ]]; then
            my_exclusions="$EXCLUSIONS"
        fi
    fi

    result=$(check_backup_folder_variable "$BACKUP_FOLDER")
    if [[ "$result" -eq 1 ]]; then
        log "ERROR" "BACKUP_FOLDER option is unset!"
        error=1
    elif [[ "$result" -eq 2 ]]; then
        log "ERROR" "Unable to locate $BACKUP_FOLDER folder!"
        error=1
    fi

    result=$(check_variable_length "$BACKUP_DONE")
    if [[ "$result" -ne 0 ]]; then
        log "ERROR" "BACKUP_DONE option is unset!"
        error=1
    fi

    result=$(check_passphrase_variable "$PASSPHRASE")
    if [[ "$result" -eq 1 ]]; then
        log "ERROR" "PASSPHRASE option is unset!"
        error=1
    elif [[ "$result" -eq 2 ]]; then
        log "ERROR" "Unable to locate $PASSPHRASE file!"
        error=1
    fi

    result=$(check_variable_length "$NEXTCLOUD_USERNAME")
    if [[ "$result" -ne 0 ]]; then
        log "ERROR" "NEXTCLOUD_USERNAME is unset!"
        error=1
    fi

    result=$(check_variable_length "$NEXTCLOUD_PASSWORD")
    if [[ "$result" -ne 0 ]]; then
        log "ERROR" "NEXTCLOUD_PASSWORD is unset!"
        error=1
    fi

    result=$(check_nextcloud_url_variable "$NEXTCLOUD_URL")
    if [[ "$result" -eq 1 ]]; then
        log "ERROR" "NEXTCLOUD_URL is unset!"
        error=1
    elif [[ "$result" -eq 2 ]]; then
        log "ERROR" "$NEXTCLOUD_URL is not a valid URL!"
        error=1
    fi

    if [[ "$error" -eq 1 ]]; then
        exit 1
    fi

    my_files="$FILES"
    backup_folder="$BACKUP_FOLDER"
    backup_done="$BACKUP_DONE"
    passphrase="$PASSPHRASE"
    nextcloud_user="$NEXTCLOUD_USERNAME"
    nextcloud_pass="$NEXTCLOUD_PASSWORD"
    nextcloud_url="$NEXTCLOUD_URL"
    return 0
}

begin() {
    local result # 0 or 1, will help set the error var
    result=0
    log "DEBUG" "(begin) Starting begin() flow..."

    log "DEBUG" "(begin) Starting root check..."
    log "DEBUG" "(root_check) Comparing $EUID against 0..."
    result=$(root_check)
    if [[ "$result" -eq 1 ]]; then
        log "ERROR" "Are you running as root?"
        exit 1
    fi
    log "DEBUG" "(begin) Root check finished!"

    log "DEBUG" "(begin) Starting argument check..."
    result=$(argument_check)
    if [[ "$result" -eq 1 ]]; then
        log "ERROR" "Please specify the full path to your options file!"
        exit 1
    fi
    log "DEBUG" "(begin) Argument check finished!"

    log "DEBUG" "(begin) Starting required options check..."
    required_options "$options"
    log "DEBUG" "(begin) Required options check finished!"

    log "DEBUG" "(begin) begin() flow finished!"
}

main() {
    local done_filepath
    local encrypted_filepath
    local filepath
    local result # 0 or 1, will help set the error var
    log "DEBUG" "(main) Starting main() flow..."

    log "DEBUG" "(main) Executing any pre-backup scripts..."
    pre_backup
    log "DEBUG" "(main) Pre-backup scripts finished!"

    log "DEBUG" "(main) Compressing backup files..."
    filepath="$backup_folder/backup.tar.bz2"
    encrypted_filepath="$backup_folder/backup.tar.enc"
    compress_files "$filepath"
    log "DEBUG" "(main) Compression complete!"

    log "DEBUG" "(main) Encrypting $filepath"
    encrypt_file_gpg "$filepath" "$encrypted_filepath" "$passphrase"
    log "DEBUG" "(main) Encryption complete!"

    log "DEBUG" "(main) Removing $filepath"
    result=$(remove_file "$filepath")
    if [[ "$result" -eq 1 ]]; then
        log "WARN" "Unable to remove $filepath!"
    fi
    log "DEBUG" "(main) $filepath removed!"

    log "DEBUG" "(main) Copying $encrypted_filepath to Nextcloud..."
    copy_backup "$encrypted_filepath"
    log "DEBUG" "(main) Copy complete!"

    log "DEBUG" "(main) Removing $encrypted_filepath"
    result=$(remove_file "$encrypted_filepath")
    if [[ "$result" -eq 1 ]]; then
        log "WARN" "Unable to remove $encrypted_filepath!"
    fi
    log "DEBUG" "(main) $encrypted_filepath removed!"

    log "DEBUG" "(main) Executing any post-backup scripts..."
    post_backup
    log "DEBUG" "(main) Post-backup scripts finished!"

    log "DEBUG" "(main) Creating backup done file for monitoring..."
    done_filepath="$backup_folder/$backup_done"
    backup_complete "$done_filepath"
    log "DEBUG" "(main) Backup done file created!"

    log "DEBUG" "(main) main() flow finished!"
}
################
### END FLOW ###
################

###################
### START OF SCRIPT
###################
check_binaries
log "INFO" "Starting script..."
begin
main
log "INFO" "Script finished!"
