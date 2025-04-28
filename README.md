# My Backups

My Backups is a `tool` that allows you to `backup` all important directories on a Linux server/workstation, taking advantage of `compression` and `encryption` and transferring the compressed and encryped file to a `Nextcloud` instance.

## Prerequisites

Before you begin, enusre you have met the following requirements:

- tar v1.3+
- gpg v2.2+
- curl v7.88+
- bash 5.2+

You will also need a Nextcloud instance and a valid username/password to this instance. The script uses the device's hostname as the location to store the backup file. For example, if the Nextcloud Username is `backups` and the device's hostname is `pihole` then the Nextcloud URL and Path would look like this: `https://example.nextcloud.com/remote.php/dav/files/backups/pihole`

## Installing

This repository ignores all files in the data/ directory. It is advised that, to be able to clone future updates to this repo without clobbering your configuration, to make all modifications to your config files in the data/ directory by copying from the configs/ directory. To say it more succinctly, the configs/ folder is a template, use it as such.

To install My Backups, follow these steps:

1. Check out the repository to a machine that meets the above requirements:
`git clone https://github.com/benowe1717/backups`

2. From the folder where you cloned the repository, copy the provided config file to the data directory:
`cp configs/options.sh data/`

3. Set the variables to the locations you prefer, here is an explanation of each variable:
- BACKUP_FOLDER: This is the location that the compressed and encrypted backup file will be stored while it is built and transferred to Nextcloud
- BACKUP_DONE: A file to be used by your monitoring to determine if the backup was successful (monitor the date/time last modified)

- FILES: A text file containing all of the files and folders you want to backup, with each file or folder on their own separate line
NOTE: This file should include the full filepath. For example, if your backups repo is located in /opt then it should look like this: `/opt/backups/data/myfiles.txt`

- EXCLUSIONS: A text file containing a list of files or folders you want to exclude from the backup, with each file or folder on their own separate line
NOTE: This file should include the full filepath. For example, if your backups repo is located in /opt then it should look like this: `/opt/backups/data/myexclusions.txt`

- PASSPHRASE: A text file containing the passphrase you want to use to encrypt your backup file with GPG. This file should only have one line and should be marked as read-only (chmod 0400) and owned by the user that will run your backup script (likely root, so chown root:root)
NOTE: This file should include the full filepath. For example, if your backups repo is located in /opt then it should look like this: `/opt/backups/data/.passphrase`

- NEXTCLOUD_URL: This is the URL to your Nextcloud instance including the username, for example: https://example.nextcloud.com/remote.php/dav/files/username
- NEXTCLOUD_USERNAME: This is the username you want to use to login to Nextcloud
- NEXTCLOUD_PASSWORD: This is the password you want to use to login to Nextcloud


## Using

The best way that I've found to use this is with a cronjob. I use ansible to deploy the repository, set up the configuration, and then add the cronjob to the system. My cron file looks like this:
`0 1 * * * root /bin/bash /opt/backups/backup.sh /opt/backups/data/options.sh > /var/log/backups.log 2>&1`

If you get any errors during the backup process, you can set the DEBUG variable on line 7 to 1 and run the script again to catch errors.

## Contributing to My Backups

To contribute to My Backups, follow these steps:
1. Fork this repository
2. Create a branch: `git checkout -b <branch_name>`
3. Make your changes and commit them: `git commit -m '<commit_message>'`
4. Push to the original branch: `git push origin <project_name>/<location>`
5. Create the Pull Request
Alternatively see the GitHub documentation on [creating a pull request](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request).

## Contributors

Thanks to the following people who have contributed to this project:
- [@benowe1717](https://github.com/benowe1717)

## Contact

For help or support on this repository, follow these steps:
- [Create an issue](https://github.com/benowe1717/backups/issues)

## License

This project uses the following license: GNU GPLv3.

## Sources

- https://github.com/scottydocs/README-template.md/blob/master/README.md
- https://choosealicense.com/
- https://www.freecodecamp.org/news/how-to-write-a-good-readme-file/
