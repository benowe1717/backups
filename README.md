# ABOUT
This script is used to backup my Linux servers on a daily (well nightly) basis. The idea here is just to backup the main configuration files in use across each server and not a full system snapshot. 

# USAGE
This script does rely on a couple of things in order to work correctly:
- Linux ( I wrote and tested this on Ubuntu 20.04 LTS, Raspbian GNU/Linux 10, and Debian GNU/Linux 9 )
- NextCloud ( https://nextcloud.com/ )

Download and unpack the zip file, or git clone the repo, and:
1) Configure the myfiles.txt file to include the paths and/or files that you'd like backed up
2) Edit the .pass file and change line 3 to be the full path to myfiles.txt
3) Run the command from the .pass file on line 7 and fill in the PASS variable on line 8 with the hash output
4) Fill in the variables on lines 21-23 for your NextCloud instance
NOTE: This script does assume that a folder exists in NextCloud for your machine's hostname that you are backing up _prior_ to running the script

Once everything is configured, add this script to cron, something like this:
```0 1 * * * root /bin/bash /opt/backups/backups-polish_backup_script/backup.sh /opt/backups/backups-polish_backup_script/.pass > /var/log/backups.log 2>&1```

NOTE: Make sure to change the path to match the path where you saved the script and .pass file!