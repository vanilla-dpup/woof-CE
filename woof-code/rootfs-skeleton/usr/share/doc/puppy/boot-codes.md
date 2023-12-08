# Boot Codes

* `pfix=nocopy`: disables locking of loaded SFSs into RAM when booting from a storage that doesn't support TRIM. Loaded SFSs are locked into RAM, limited to consume half of RAM and this memory is freed automatically when running out of memory.
* `pfix=copy`: enables locking of loaded SFS to RAM even if boot device supports TRIM.
* `pfix=ram`: disables persistency and enables locking of loaded SFS to RAM even if boot device supports TRIM.
* `pmedia=cd`: enables search for a partition containing DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs.
* `pmedia=usbflash`: activates PUPMODE 13 (see [Persistency](persistency.md)) and restricts the search for Puppy SFSs and DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs to USB devices.
* `pupsfs=UUID|label`: specifies the partition containing Puppy SFSs using its UUID or label, and disables search for this partition.
* `psave=UUID|label`: specifies the partition containing DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs using its UUID or label, and disables search for this partition.
* `psubdir=/relative/path`: specifies a subdirectory for Puppy SFSs and DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs.
* `waitdev=seconds`: specifies the timeout for search for Puppy SFSs and DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs. If unspecified, the default is 5 seconds.
* `pfix=fsck`: enables file system error repair for save files.
* `pfix=fsckp`: enables file system error repair for mounted partitions.
* `pfix=rdsh`: drops to a rescue shell at the end of the early boot process.
* `pfix=nox`: disables automatic start of the graphical desktop.
* `loglevel=number`: specifies the verbosity level, using a printk log level: the default is 3 (KERN_ERR) and 7 (KERN_DEBUG) makes {/initrd,}/tmp/bootinit.log extra verbose.
