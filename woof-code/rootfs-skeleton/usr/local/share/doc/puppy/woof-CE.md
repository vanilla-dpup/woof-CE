# woof - the Puppy builder

This is a fork of [woof-CE](https://github.com/puppylinux-woof-CE/woof-CE), the build system used to produce [Puppy Linux](https://puppylinux.com) releases.

The goal is to build something similar to [DebianDog](https://debiandog.github.io/doglinux/), a highly [Debian](https://www.debian.org/)-compatible, portable, modular, hackable and lightweight distro with core features of [Puppy Linux](https://puppylinux.com), a distro that -
* Provides the best features of dpup (Debian-based Puppy), but with big improvements
  * Boots to a lightweight desktop environment with a variety of applications
  * Supports non-persistent, fully persistent or "persistent-on-demand" sessions where the user can decide whether or not to save, and when
     * But with more efficient, fast saving that reduces writing to storage
     * But with improved support for encryption and sandboxing for unprivileged applications
     * But with easier and more flexible session management
  * Supports extra read-only layers (sfs_load)
     * But with flexible naming and control over the stacking order
  * Provides a fully functional package manager and [Flatpak](https://flatpak.org/)
     * But with better compatibility and without risk of breakage on update
* Provides a build system that makes it easy to reproduce, customize and develop

![Vanilla Dpup screenshot](https://vanilla-dpup.github.io/screenshot3.png)

## Features

### Simplicity

* SFSs don't need to be "queued" by the user for loading at boot time: instead, the init script loads all SFSs under `psubdir` (if specified) and the partition root, under both the save partition and the boot partition. SFSs are sorted numerically before loading, so 2something.sfs is loaded before 10something.sfs. This allows loading of extra SFSs without persistency and allows the user to control the stacking order. The stacking order of the traditional *drv SFS is retained, for backward compatibility.
* Support for PUPMODEs other than 5 (live), 12 (automatic persistency) and 13 (on-demand persistency) is gone.
* Support PUPMODE 13 with periodic saving is gone. The user can run `save2flash` to save now, or save at shutdown.
* Support for the devx SFS is gone and development packages can be installed individually, without having to download the entire devx.
* busybox init, /etc/inittab, plogin, autologin, etc' are replaced with a simple init implementation (see woof-code/rootfs-petbuilds/init).
* Bootflash lets the user select what PUPMODE to use: if it's 12 or 13, an empty save file or folder is created.
* The "first shutdown" prompt that offers the user to save is gone, to make non-persistent installations less annoying to use without hacks to bypass this prompt: instead, users that want persistency can use the pupsave tool to create a save file/folder.
* The build output is produced by Bootflash, with a sparse image and a loop device as the installation destination.
* `pdrv` is gone: the partition containing Puppy files can be specified only using `pupsfs=$UUID`.
* SAVEMARK and SAVESPEC are gone: the partition containing the save file/folder can be specified only using `psave=$UUID`.
* Rarely-used boot codes like `pimod` and `pwireless` are gone.
* Puppy's elaborate configuration wizards are replaced with simple [yad](https://github.com/step-/yad)-based tools that do one thing: for example, a hostname changer and a locale changer.
* `puppyhelp` displays short and easy to maintain .md files, instead of displaying outdated and lengthy .html files using a web browser. Documentation is expanded to cover topics like boot codes, PUPMODEs and even rebuilding the currently running OS, allowing the user to learn the new system in offline-first manner.

### Compatibility

* coreutils, util-linux, etc' are not replaced with symlinks to busybox, because this breaks compatibility with the upstream distro.
* Core Puppy scripts are moved to /usr/local and tools that override upstream distro files (like setup-spot) use /usr/local/{,s}bin and rely on the order of PATH. Essentially, Puppy becomes a thin layer on top of the upstream distro that mostly resides in /usr/local. This makes upstream distro package updates safe, because they no longer remove Puppy's hooks.
* The Puppy way of doing things is replaced with the upstream distro way of doing things. For example, rc.country is gone, and so is the hack of exporting LANG in /etc/profile. Instead, one should use /etc/default/locale, /etc/locale.gen, locale-gen, etc'.
* Themes are supported, but not included by default: [themes break applications](https://stopthemingmy.app/), they're hard to maintain and non-native widgets in modern browsers or Flatpak applications make theming consistency nearly impossible.
* petget provides limited support for .pet packages.

### Resource Consumption

* Copying of SFSs is enabled automatically only if Puppy files reside on storage that doesn't support TRIM and assumed to be a slow device, like a hard drive, a memory card, a flash drive or a DRAM-less SSD.
* SFSs are not copied to a ramdisk (`pfix=ram|copy` or automatic) but locked in page cache (see woof-code/rootfs-petbuilds/sfslock) instead, freeing ramdisk space.
* The RAM occupied by cached SFSs is freed automatically (using [PSI](https://docs.kernel.org/accounting/psi.html) or OOM score adjustment) if needed.
* SFSs are prioritized and lower priority SFSs are not cached when cached SFSs occupy half of available RAM.
* If possible, save files are created as [sparse files](https://en.wikipedia.org/wiki/Sparse_file), to reduce writing to disk and retain usable free space in the partition.
* Encrypted save files are implemented using [fscrypt](https://www.kernel.org/doc/html/latest/filesystems/fscrypt.html) instead of LUKS, allowing encryption of specific directories (like the user's home directory) rather than the entire save file.

### Speed

* The init script (/etc/rc.d/rc.sysinit) and the shutdown script (/etc/rc.d/rc.shutdown) are shorter and much faster.
* SFSs can use [EROFS](https://docs.kernel.org/filesystems/erofs.html) instead of [Squashfs](https://docs.kernel.org/filesystems/squashfs.html) and all built-in SFSs use the former.
* Caching of SFSs in RAM (`pfix=ram|copy` or automatic) happens in the background while the boot process continues.
* 1download and 3builddistro are reimplemented using [debootstrap](https://wiki.debian.org/Debootstrap) and chroot environments. Build times are much shorter than upstream's and woof-CE itself is more portable.
* `save2flash` is much faster because it preallocates space when files grow and only copies appended or modified blocks when files change.
* The pup-advert-blocker ad blocking tool is reimplemented using a [NSS module](https://www.gnu.org/software/libc/manual/html_node/Name-Service-Switch.html) that checks whether or not a domain should be blocked using binary search on a sorted array of [xxHash](https://github.com/Cyan4973/xxHash) hashes, instead of appending MBs of text to /etc/hosts and later scanning it line by line.
* firewall_ng is enabled by default, ported to [nftables](https://netfilter.org/projects/nftables) and much simplified: it produces a short list of rules what describe packets to accept, instead of explictly blocking many kinds of packets and accepting anything else. In addition, it no longer does things that make sense on a router or a server, but don't do anything in an endpoint.
* Files spilled to the save layer on `apt upgrade` or metadata change (like `chmod`) are cleaned up on update if possible, shrinking the save layer and preventing performance degradation as more and more files reside on disk without the SFS advantages of compression and caching in RAM.

### Security

* Save folders support encryption, using [fscrypt](https://www.kernel.org/doc/html/latest/filesystems/fscrypt.html).
* A [Landlock](https://docs.kernel.org/userspace-api/landlock.html)-based sandbox restricts file system access for applications running as spot and prevents spot from reading or writing files under the save partition. The sandbox blocks access to /root even if permissions are 777 and blocks attempts to bypass it by accessing /initrd/mnt/dev_save/*save/upper/root instead. This reduces compatibility with Puppy, because spot can only run applications installed to / and can't run "portable" applications that reside on the save partition.
* Most legacy X11 applications work thanks to [Xwayland](https://wayland.freedesktop.org/xserver.html), which is unprivileged and sandboxed.
* Common sysfs hardening recommendations are applied out of the box.

### Modernization

* Only dpup ([Debian](https://www.debian.org/) or [Devuan](https://www.devuan.org/) based Puppy) is supported.
* Only Wayland is supported: support for X.Org and tools that modify xorg.conf is gone.
* Only [PipeWire](https://pipewire.org/) is supported: support for plain ALSA and [PulseAudio](https://www.freedesktop.org/wiki/Software/PulseAudio/) is gone.
* Screenshots, cropped screenshots and screen recording are supported out of the box, with key bindings.
* Support for ROX-Filer is gone, and the "source of truth" regarding file associations and default applications is xdg-utils. /usr/local/bin/default* are provided for backward compatibility with Puppy.
* usrmerge is mandatory: support for the deprecated file system layout with separate /lib and /usr/lib, is gone.
* Only [overlay](https://docs.kernel.org/filesystems/overlayfs.html) is supported: support for aufs is gone.
* PPM is gone: packages in the build come from the upstream distro, rootfs-packages or rootfs-petbuilds (built from source).
* Remaining old tools that use [gtkdialog](https://github.com/puppylinux-woof-CE/gtkdialog) are ported to [yad](https://github.com/step-/yad) and the former is gone.
* kernel-kit builds the [Debian](https://www.debian.org/) kernel source and support for other types of kernels is gone.
* kernel-kit's firmware picker is gone: fdrv is built by moving /usr/lib/firmware out of the main SFS.
* ISO images are gone: the woof-CE build output is a bootable flash drive image and `isoboot` is gone.
* ntfs-3g is replaced with [ntfs3](https://www.kernel.org/doc/html/next/filesystems/ntfs3.html).
* ext2 and ext3 save files are gone: all save files (including encrypted ones) use ext4 (without journaling).
* Bootflash supports only syslinux and efilinux, with one partition layout: a small FAT32 boot partition and a big ext4 (without journaling) or F2FS partition for SFSs and persistency.
* mke2fs is no longer preconfigured to disable modern ext4 features like `64bit` and `metadata_csum_seed`, because maintaining compatibility with ancient boot loaders is no longer a concern.
* initrd is zstd-compressed and built from rootfs binaries instead of a prebuilt, outdated and unmaintained set of static executables.
* initrd supports file system repair for exFAT, FAT32 and F2FS partitions, not just ext{2,3,4}.

## Directory Structure

* initrd-progs/ contains the initramfs skeleton
  * initrd-progs/0initrd/init is the early init script, which searches for Puppy files, sets up an overlay file system and `switch_root`s into it
* kernel-kit/ contains a tool that builds Puppy-compatible kernels from the [Debian](https://www.debian.org/) kernel
* woof-distro/ contains configuration files
  * woof-distro/x86_64/debian/trixie64 builds a [Debian](https://www.debian.org/) 13 based Puppy, featuring [dwl](https://codeberg.org/dwl/dwl) with the [snail layout](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/snail) and [yambar](https://codeberg.org/dnkl/yambar), or [labwc](https://labwc.github.io/) with [waybar](https://github.com/Alexays/Waybar)
    * woof-distro/x86_64/debian/trixie64/DISTRO_SPECS contains the distro name and version
    * woof-distro/x86_64/debian/trixie64/DISTRO_PKGS_SPECS-debian-trixie contains a list of [Debian](https://www.debian.org/) 13 packages to include
    * woof-distro/x86_64/debian/trixie64/_00build.conf contains a list of packages to build from source (PETBUILDS) and other settings
* woof-code/ contains most of woof-CE itself and the Puppy skeleton (minus initramfs)
  * woof-code/rootfs-skeleton contains the Puppy root file system skeleton
    * rootfs-skeleton/etc/rc.d/rc.sysinit is the init script
    * rootfs-skeleton/usr/local/sbin/pupsave creates save folders and files, with optional encryption
    * rootfs-skeleton/usr/local/sbin/{save2flash,snapmergepuppy.overlay} implement saving under PUPMODE 13
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
  * woof-code/2buildkernel builds the kernel
  * woof-code/3builddistro builds the packages specified in `$PETBUILDS` inside sandbox3/devx, then adds them and packages under rootfs-packages/ to sandbox3/rootfs, then builds bootable distro images

## Usage

	sudo apt-get install -y --no-install-recommends debootstrap

Then:

	export DISTRO_VARIANT=labwc

Or:

	export DISTRO_VARIANT=dwl

Then:

	./merge2out woof-distro/x86_64/debian/trixie64
	cd ../woof-out_*
	./1download
	./2buildkernel
	./3builddistro
