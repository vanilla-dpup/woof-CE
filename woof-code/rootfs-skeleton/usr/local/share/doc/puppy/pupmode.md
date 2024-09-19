# PUPMODE

[Since the Puppy Linux 2.x days](https://bkhome.org/archive/puppylinux/development/howpuppyworks.html), Puppy Linux supports various kinds of persistent and non-persistent sessions, also known as "PUPMODEs".

## PUPMODE 5: No Persistency

Changes to the layered file system at / reside in RAM.

DISTRO_NAME boots with PUPMODE 5 when `pfix=ram` is specified or when neither a save folder nor a save file is found. To switch from PUPMODE 12 or 13 to PUPMODE 5, add `pfix=ram`.

## PUMODE 13: On-Demand Persistency

Changes to the layered file system at / reside in RAM and can be copied to a save folder or file using `save2flash` and during shutdown.

DISTRO_NAME boots with PUPMODE 13 when a save folder or file is found and `pmedia=usbflash` or the save partition is a removable drive but `pmedia` is unspecified or `pmedia=cd`. Therefore, to switch from PUPMODE 13 to 12, replace `pmedia=usbflash` with `pmedia=atahd`.

PUPMODE 13 can increase the lifespan of flash drives by reducing the number of writing operations, reduce read times of modified files and reduce therisk of data loss when using an unreliable disk.

## PUMODE 12: Full Persistency

Changes are saved directly to a save folder or a save file, which is used as the upper, writable layer of the layered file system at /.

DISTRO_NAME boots with PUPMODE 12 when a save folder or file is found but the other criteria for PUPMODE 13 are not met. Therefore, to switch from PUPMODE 12 to 13, replace `pmedia=atahd` with `pmedia=usbflash`.

## Implementation Details

PUPMODE is written to /etc/rc.d/PUPSTATE during the boot process.

Under any PUPMODE, the writable layer is accessible at /initrd/pup_rw.

Under PUPMODE 5, /initrd/pup_rw is a [tmpfs](https://www.kernel.org/doc/html/latest/filesystems/tmpfs.html): it's writeable but non-persistent because its contents reside in RAM.

Under PUPMODE 12, /initrd/pup_rw points to the save folder or mounted save file.

Under PUPMODE 13, the save folder or file is accessible through /initrd/pup_ro1 and added to the stack as the top read-only layer, below /initrd/pup_rw. Therefore, /initrd/pup_rw contains all changed made in the current session. `save2flash` runs `snapmergepuppy`, which synchronizes /initrd/pup_ro1 with /initrd/pup_rw by copying new files, deleting deleted files, updating file metadata and replacing modified files. The modified files remain in /initrd/pup_rw and continue to "cover" the files in /initrd/pup_ro1, to make the files on disk safer to modify, allow retry if saving has failed, and make recently changed files faster to read from and modify again by keeping them in RAM.
