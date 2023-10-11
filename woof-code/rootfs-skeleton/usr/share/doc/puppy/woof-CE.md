# woof - the Puppy builder

This is a fork of [woof-CE](https://github.com/puppylinux-woof-CE/woof-CE).

The goal is to build something similar to [DebianDog](https://debiandog.github.io/doglinux/), a highly [Debian](https://www.debian.org/)-compatible "live" distro with a layered file system, but with core features of [Puppy Linux](https://puppylinux.com), a distro that -
* Provides a lightweight desktop environment and a variety of applications
* Provides a fully functional package manager, [Flatpak](https://flatpak.org/) and support for extra read-only layers (sfs_load)
* Supports non-persistent, fully persistent or "persistent-on-demand" sessions where the user can decide whether or not to save, and when
* Has just a drop or two of Puppy's secret sauce: all kinds of legacy cruft, technical debt and complex in-house solutions are gone, to reduce size, speed things up, increase compatibility with Debian, make updates safe and ensure the project's sustainability with very few developers

## Overview

This fork strips woof-CE down to the bare essentials:

* Only dpup ([Debian](https://www.debian.org/) or [Devuan](https://www.devuan.org/) based Puppy) is supported.
* Support for X.Org and tools that modify xorg.conf is gone. Only Wayland is supported.
* Support for plain ALSA and [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) is gone. Only [PipeWire](https://pipewire.org/) is supported.
* Support for ROX-Filer is gone, and the "source of truth" regarding file associations and default applications is xdg-utils. /usr/local/bin/default* are provided for backward compatibility with Puppy.
* Most of 0setup, 1download, 2createpackages and 3builddistro is reimplemented using [debootstrap](https://wiki.debian.org/Debootstrap). Build times are much shorter than upstream's.
* PPM and support for .pet packages are gone: packages in the build come from rootfs-packages or rootfs-petbuilds (built from source).
* The only supported kind of kernel packages is the "huge" one, and fdrv is built by moving /usr/lib/firmware out of the main SFS.
* Support for aufs is gone. Only [overlay](https://docs.kernel.org/filesystems/overlayfs.html) is supported.
* ISO images are gone: the woof-CE build output is a bootable flash drive image and `isoboot` is gone.
* Support for PUPMODEs other than 5 (live), 12 (automatic persistency) and 13 (on-demand persistency) is gone.
* Support PUPMODE 13 with periodic saving is gone. The user can run `save2flash` to save now, or save at shutdown.
* The partition containing Puppy files can be specified only using `pupsfs=$UUID`.
* Support for SAVEMARK and SAVESPEC is gone. The partition containing the save file/folder can be specified only using `psave=$UUID`.
* Support for pimod and pwireless is gone.
* ntfs-3g is replaced with [ntfs3](https://www.kernel.org/doc/html/next/filesystems/ntfs3.html).
* Support for the devx SFS is gone. Development packages are installed inside a copy of the main SFS during the build, but don't make it into the build output.
* The Puppy way of doing things is replaced with the upstream distro way of doing things. For example, rc.country is gone, and so is the hack of exporting LANG in /etc/profile. Instead, one should use /etc/default/locale, /etc/locale.gen, locale-gen, etc'.
* Themes are gone. [Themes break applications](https://stopthemingmy.app/) and they're hard to maintain.
* coreutils, util-linux, etc' are not replaced with symlinks to busybox, because this breaks compatibility with the upstream distro.
* busybox init, /etc/inittab, plogin, autologin, etc' are replaced with a simple init implementation (see woof-code/rootfs-petbuilds/init).
* Legacy cruft is removed from the init script (/etc/rc.d/rc.sysinit) and it's much faster. Daemons like udev and dbus are started using their init scripts.
* Some core Puppy scripts that override the upstream distro (including run-as-spot wrappers created by setup-spot) are moved to /usr/local/{,s}bin and PATH makes the shell prefer them. This makes package updates safe, because they no longer remove Puppy's hooks.

Other changes:

* All save files (including encrypted ones) use ext4, with or without journaling.
* Bootflash in upstream supports FAT32 and f2fs, using syslinux, extlinux or efilinux. This fork adds ext4 support.
* If possible, save files are created as [sparse files](https://en.wikipedia.org/wiki/Sparse_file), to reduce writing to disk and retain usable free space in the partition.
* Copying of SFSs to RAM (`pfix=ram|copy`) happens later in the boot process and it's implemented differently. SFSs are cached and not copied to the ramdisk (see woof-code/rootfs-petbuilds/sfslock), leaving more usable ramdisk space, and the memory spent on SFSs is freed automatically (using OOM score adjustment) if needed. However, this also means that the boot partition remains mounted even when using `pfix=ram`. In addition, SFSs are prioritized and lower priority SFSs are not cached when cached SFSs occupy half of available RAM.
* Copying of SFSs is enabled automatically only Puppy files reside on a hard drive or on removable storage that doesn't support TRIM (which is assumed to be a slow device, like a memory card, a flash drive or a DRAM-less SSD).
* EXTRASFSLIST is now managed automatically and SFSs don't need to be "queued" by the user for loading at boot time. Instead, the init script loads all SFSs under psubdir (if specified) and the partition root, under both the save partition or the boot partition. SFSs are sorted numerically before loading, so 2something.sfs is loaded before 10something.sfs. This allows loading of extra SFSs without persistency and allows the user to control the stacking order. The stacking order of the traditional *drv SFS is retained, for backward compatibility.
* The [Landlock](https://docs.kernel.org/userspace-api/landlock.html)-based sandbox that restricts file system access for applications running as spot is stricter and also prevents spot from reading or writing files under the save partition. The sandbox blocks access to /root even if permissions are 777, but without this new restriction, spot can access /initrd/mnt/dev_save/*save/upper/root instead, to bypass the sandbox. This breaks compatibility with Puppy, because spot can only run applications installed to / and can't run "portable" applications that reside on the save partition.

## Directory Structure

* initrd-progs/ contains the initramfs skeleton
  * initrd-progs/0initrd/init is the early init script, which searches for Puppy files, sets up an overlay file system and `switch_root`s into it
* kernel-kit/ contains a tool that builds Puppy-compatible kernels
* woof-distro/ contains configuration files
  * woof-distro/x86_64/debian/trixie64 builds a [Debian](https://www.debian.org/) 13 based Puppy, featuring [dwl](https://github.com/djpohly/dwl) with the [snail layout](https://github.com/djpohly/dwl/wiki/snail) and [yambar](https://codeberg.org/dnkl/yambar), or [labwc](https://labwc.github.io/) with [sfwbar](https://github.com/LBCrion/sfwbar)
    * woof-distro/x86_64/debian/trixie64/DISTRO_SPECS contains the distro name and version
    * woof-distro/x86_64/debian/trixie64/DISTRO_PKGS_SPECS-debian-trixie contains a list of [Debian](https://www.debian.org/) 13 package sto include
    * woof-distro/x86_64/debian/trixie64/_00build.conf contains a list of packages to build from source (PETBUILDS) and other settings
* woof-code/ contains most of woof-CE itself and the Puppy skeleton (minus initramfs)
  * woof-code/rootfs-skeleton contains the Puppy root file system skeleton
    * rootfs-skeleton/etc/rc.d/rc.sysinit is the init script
    * rootfs-skeleton/usr/sbin/shutdownconfig implements the save/no save prompt shown when shutting down under PUPMODE 5
    * rootfs-skeleton/usr/sbin/{save2flash,snapmergepuppy.overlay} implement saving under PUPMODE 13
    * rootfs-skeleton/etc/rc.d/rc.shutdown takes care of saving on shutdown
    * rootfs-skeleton/usr/local/sbin/{reboot,poweroff} run /etc/rc.d/rc.shutdown, then pass control to `/sbin/$0`
    * rootfs-skeleton/root/.profile starts the graphical desktop
  * woof-code/rootfs-petbuilds contains recipes for building Puppy-specific packages or packages with Puppy-specific customization, from source
    * woof-code/rootfs-petbuilds/init provides a simple init implementation that runs /etc/rc.d/rc.sysinit and a login shell
    * woof-code/rootfs-petbuilds/spot-pkexec implements a sandbox for unprivileged applications
    * woof-code/rootfs-petbuilds/ram-saver changes the memory allocator settings to reduce RAM consumption
    * woof-code/rootfs-petbuilds/sfslock locks a file into the page cache to speed up reading from it
  * woof-code/rootfs-packages contains Puppy-specific tools
  * woof-code/1download builds:
    * sandbox3/rootfs, a basic root file system template
    * sandbox3/devx, a copy of rootfs with development packages on top
  * woof-code/3builddistro builds the packages specified in `$PETBUILDS` inside sandbox3/devx, then adds them and packages under rootfs-packages/ to sandbox3/rootfs, then builds bootable distro images

## Usage

	sudo apt-get install -y --no-install-recommends dc debootstrap librsvg2-bin zstd xml2 syslinux-utils extlinux

Then:

	export DISTRO_VARIANT=labwc

Or:

	export DISTRO_VARIANT=dwl

Then:

	./merge2out woof-distro/x86_64/debian/trixie64
	cd ../woof-out_*
	./1download
	./3builddistro
