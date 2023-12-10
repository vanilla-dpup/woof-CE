# SFS Modules

SFS modules are [Squashfs](https://docs.kernel.org/filesystems/squashfs.html) images containing a read-only directory hierarchy. DISTRO_NAME uses [overlayfs](https://docs.kernel.org/filesystems/overlayfs.html) to stack SFSs on top of each other and present their contents as a unified directory hierarchy.

## Loading

The early init script loads all SFSs in the save partition or boot partition, from the partition root or `psubdir` (see [Boot Codes](boot-codes.md)). To speed up access to files inside loaded SFSs that reside on slow media like flash drives, the init script reads them into the page cache (see documentation for `pfix=nocopy`).

It is possible to load a SFS by opening it using the file manager, without copying it to the right location and rebooting the system, but this is implemented differently, with various limitations (like inability to replace existing files), the SFS is not cached and the loading operation may require writing to disk.

## Stacking Order

For backward compatibility with [Puppy Linux](https://puppylinux.com), DISTRO_NAME uses the same stacking order (from top to bottom):

	adrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs
	ydrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs
	bdrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs
	puppy_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs (!)
	nlsx_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs
	docx_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs
	kbuild_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs
	fdrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs (!)
	zdrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs (!)

All SFss except those marked with (!) are optional and DISTRO_NAME should be able to boot without them.

Users interested in running a customized, non-persistent DISTRO_NAME, can achieve this using the SFSs above puppy_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs. For example, if adrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs contains etc/rc.d/rc.sysinit, this file overrides the one in puppy_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs and the contents of /etc/rc.d/rc.sysinit match those of the file in adrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs. Any file in adrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs that is not present in any SFS below it is "added" to /. To create a snapshot of a non-persistent session of DISTRO_NAME, create adrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs from the contents of /initrd/pup_rw (see [Persistency](persistency.md)).

All other SFSs are sorted numerically before they're appended to the stack, after zdrv_DISTRO_FILE_PREFIX_DISTRO_VERSION.sfs:

	abc.sfs
	1_abc.sfs
	2-abc.sfs
	10_-abc.sfs

Therefore, to control the stacking order of these SFSs, prefix their names with numbers.

## Creating SFS Modules

To create /tmp/app.sfs from /tmp/app:

	mksquashfs /tmp/app /tmp/app.sfs -comp zstd -Xcompression-level 19 -b 256K -no-exports -no-xattrs

To load app.sfs on startup, place it under the root (or `psubdir`, if set) of the save partition or boot partition.

Once app.sfs is loaded, /tmp/app/usr/bin/a can be accessed through /usr/bin/a.

See `man mksquashfs` for more SFS creation options.
