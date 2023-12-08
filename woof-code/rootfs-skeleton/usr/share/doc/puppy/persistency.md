# Persistency

[Since the Puppy Linux 2.x days](https://bkhome.org/archive/puppylinux/development/howpuppyworks.html), Puppy Linux supports various kinds of persistent and non-persistent sessions.

Internally, the chosen persistency mode is written to PUPMODE in /etc/rc.d/PUPSTATE.

## PUPMODE 5: No Persistency

Changes to the layered file system at / reside in RAM and a shutdown prompt offers the user to create DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs and save the changes to it.

DISTRO_NAME boots with PUPMODE 5 when `pfix=ram` (see [Boot Codes](boot-codes.md)) is specified or when neither DISTRO_FILE_PREFIXsave/ nor DISTRO_FILE_PREFIXsave.4fs are found.

## PUMODE 13: On-Demand Persistency

Changes to the layered file system at / reside in RAM and can be copied to DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs using `save2flash` and during shutdown.

DISTRO_NAME boots with PUPMODE 13 when DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs is found and `pmedia=usbflash` or the save partition is a removable drive but `pmedia` is unspecified or `pmedia=cd`.

By default, DISTRO_NAME images contain DISTRO_FILE_PREFIXsave/, making PUPMODE 13 the default when booting from a flash drive.

PUPMODE 13 can increase the lifespan of flash drives by reducing the number of writing operations, reduce read times of modified files and reduce therisk of data loss when using an unreliable disk.

## PUMODE 12: Full Persistency

Changes are saved directly to DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs, which is used as the upper, writable layer of the layered file system at /.

DISTRO_NAME boots with PUPMODE 12 when DISTRO_FILE_PREFIXsave/ or DISTRO_FILE_PREFIXsave.4fs is found but the other criteria for PUPMODE 13 are not met.
