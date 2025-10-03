psnapcp is a fast file synchronization tool used by snapmergepuppy to save changes, as an alternative to `cp -a` and `{touch,chown,chmod} --reference`.

Speed is achieved by shrinking the file on disk or increasing its size to match the file in RAM, then synchronizing changed blocks to disk (if any) and synchronizing metadata changes. Some frequently-changing binary files mostly grow over time or change only around the beginning of the file (headers) or end (for example, sqlite WAL files written by browsers), so psnapcp can reduce writing to 1% of the file in many cases.
