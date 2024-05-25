# Persistency

[Since the Puppy Linux 2.x days](https://bkhome.org/archive/puppylinux/development/howpuppyworks.html), Puppy Linux supports various kinds of persistent and non-persistent sessions, also known as "PUPMODEs". Bootflash, the DISTRO_NAME installer, allows one to select the desired persistency mode at installation time, but the persistency mode can be changed later by changing the [Boot Codes](boot-codes.md) set by Bootflash.

In non-persistent sessions, there is a writeable, non-persistent, [tmpfs](https://www.kernel.org/doc/html/latest/filesystems/tmpfs.html) layer on top of the stack of loaded SFSs (see [SFS Modules](sfs_load.md)). The changes saved to this layer are lost on shutdown. Persistency is achieved by replacing this layer with DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs, or by synchronizing DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs with the contents of this layer.

## PUPMODE 5: No Persistency

Changes to the layered file system at / reside in RAM and a shutdown prompt offers the user to create DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs and save the changes to it.

DISTRO_NAME boots with PUPMODE 5 when `pfix=ram` is specified or when neither DISTRO_FILE_PREFIXsave/ nor DISTRO_FILE_PREFIXsave.4fs are found. Therefore, to switch to PUPMODE 5 to 12 or 13, remove `pfix=ram` or delete DISTRO_FILE_PREFIXsave/ and DISTRO_FILE_PREFIXsave.4fs.

## PUMODE 13: On-Demand Persistency

Changes to the layered file system at / reside in RAM and can be copied to DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs using `save2flash` and during shutdown.

DISTRO_NAME boots with PUPMODE 13 when DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs is found and `pmedia=usbflash` or the save partition is a removable drive but `pmedia` is unspecified or `pmedia=cd`. Therefore, to switch from PUPMODE 13 to 12, replace `pmedia=usbflash` with `pmedia=atahd`.

By default, DISTRO_NAME images contain DISTRO_FILE_PREFIXsave/, making PUPMODE 13 the default when booting from a flash drive.

PUPMODE 13 can increase the lifespan of flash drives by reducing the number of writing operations, reduce read times of modified files and reduce therisk of data loss when using an unreliable disk.

## PUMODE 12: Full Persistency

Changes are saved directly to DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs, which is used as the upper, writable layer of the layered file system at /.

DISTRO_NAME boots with PUPMODE 12 when DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs is found but the other criteria for PUPMODE 13 are not met. Therefore, to switch from PUPMODE 12 to 13, replace `pmedia=atahd` with `pmedia=usbflash`.

## Implementation Details

Internally, the chosen persistency mode is written to PUPMODE in /etc/rc.d/PUPSTATE.

Under any PUPMODE, the writable layer is accessible at /initrd/pup_rw.

Under PUPMODE 12, /initrd/pup_rw points to DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs instead of a [tmpfs](https://www.kernel.org/doc/html/latest/filesystems/tmpfs.html).

Under PUPMODE 13, DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs is accessible through /initrd/pup_ro1 and added to the stack as the top read-only layer. Therefore, /initrd/pup_rw contains all changed made in the current session. `save2flash` runs `snapmergepuppy`, which synchronizes /initrd/pup_ro1 with /initrd/pup_rw by copying new files, deleting deleted files, updating file metadata and replacing modified files. The modified files remain in /initrd/pup_rw and continue to "cover" the files in /initrd/pup_ro1, to make the files on disk safer to modify, allow retry if saving has failed, and make recently changed files faster to read from and modify again by keeping them in RAM.
