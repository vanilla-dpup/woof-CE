# pupsave

pupsave is a tool that creates save folders and save files.

Save files hold all changes in a single file, making them easy to backup and restore, and they support any underlying file system. However, they are limited in size and reserve space on the partition if the file system doesn't support sparse files.

Save folders don't support all file systems, but they're not limited in size, they don't preallocate space and they're less likely to suffer from file system corruption. If in doubt, use a folder.

Both save files and folders support encryption, and pupsave offers choice between:
* Encryption of all files inside the save folder or file: better tamper resistance and privacy (if data is stolen) at the cost of slower reading and writing
* Encryption of the home directory: smaller tamper resistance and privacy gains but with reduced overhead
* No encryption at all

By default, DISTRO_NAME images contain a save folder with an encrypted home folder and passphrase "woofwoof".
