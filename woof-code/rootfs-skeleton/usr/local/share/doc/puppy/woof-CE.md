# woof - the Puppy builder

This is a heavily modified and cleaned up fork of [woof-CE](https://github.com/puppylinux-woof-CE/woof-CE), the build system used to produce [Puppy Linux](https://puppylinux.com) releases.

The goal is to build something similar to [DebianDog](https://debiandog.github.io/doglinux/), a highly [Debian](https://www.debian.org/)-compatible, portable, modular, hackable and lightweight distro with core features of [Puppy Linux](https://puppylinux.com).

The history of this fork and the relationship with other projects is documented [here](family-tree.md).

# Major Changes in This Fork

## Build System

* Narrow focus
    * Builds must be [Debian](https://www.debian.org/) or [Devuan](https://www.devuan.org/) based
    * 1download and 3builddistro are reimplemented using [debootstrap](https://wiki.debian.org/Debootstrap) and this is the only dependency of woof-CE
    * usrmerge is mandatory
    * Only Wayland, [PipeWire](https://pipewire.org/) and [overlay](https://docs.kernel.org/filesystems/overlayfs.html)
    * The "source of truth" regarding file associations and default applications is xdg-utils: support for ROX-Filer is gone
* Simplified kernel-kit
    * It rebuilds the [Debian](https://www.debian.org/) kernel with minimal customization (see kernel-kit/debian-diffconfigs)
    * The firmware picker is gone: fdrv is built from [Debian](https://www.debian.org/) firmware packages
    * The kernel is built inside a chroot environment created by `1download`
        * The kernel and third party drivers installed by the user are all built using the same compiler
        * The built distro can rebuild itself
* The build output is produced by Bootflash, with a sparse image and a loop device as the installation destination
    * It's a bootable flash drive image: ISO images and `isoboot` are gone
    * Writing the build output to a flash drive is equivalent to using Bootflash to install to a flash drive 
* coreutils, util-linux, etc' are not replaced with symlinks to busybox, because this breaks compatibility with the upstream distro
* initrd is built from rootfs binaries instead of a prebuilt, outdated and unmaintained set of static executables

## In-House Tools

* Upstream distro package updates are safe because scripts that override upstream distro files (like `poweroff`) are moved to /usr/local/{,s}bin
* Puppy's configuration wizards are replaced with simple [yad](https://github.com/step-/yad)-based tools that do one thing: for example, a hostname changer and a locale changer
* Screenshot tool, with key bindings
    * Whole monitor screenshot
    * Cropped screenshot
    * Whole monitor recording
    * Cropped recording
* Improved Bootflash
    * Lets the user select what PUPMODE to use: if it's 12 or 13, an empty save file or folder is created
    * Supports only syslinux and efilinux, with one partition layout
        * A small FAT32 boot partition
        * A big ext4 (without journaling) or F2FS partition for SFSs and persistency
    * mke2fs is no longer preconfigured to disable modern ext4 features like `64bit` and `metadata_csum_seed`, because maintaining compatibility with ancient boot loaders is no longer a concern
* `puppyhelp` is expanded to cover topics like boot codes, PUPMODEs and rebuilding the currently running OS
* PPM is gone but petget provides limited support for .pet packages

## Boot Process

* It's much faster and simpler
    * initrd iz zstd-compressed, making it faster to decompress
    * The init and shutdown scripts (/etc/rc.d/rc.{sysinit,shutdown}) are shorter and much faster
    * busybox init, /etc/inittab, plogin, autologin, etc' are replaced with a single process (see woof-code/rootfs-petbuilds/init)
* Fewer boot codes and configuration files
    * `pdrv` is gone: the partition containing Puppy files can be specified only using `pupsfs=$UUID`
    * SAVEMARK and SAVESPEC are gone: the partition containing the save file/folder can be specified only using `psave=$UUID`
    * Rarely-used boot codes like `pimod` and `pwireless` are gone
* [zram](https://docs.kernel.org/admin-guide/blockdev/zram.html) swap is always enabled: if a swap file is present, it acts as slower fallback when the former is full
* Files spilled to the save layer after `apt upgrade` or metadata change (like `chmod`) are cleaned up if possible, shrinking the save layer and preventing performance degradation
* initrd supports file system repair for exFAT, FAT32 and F2FS partitions, not just ext{2,3,4}

## Persistency

* Fewer PUPMODEs: only 5 (live), 12 (automatic persistency) and 13 (on-demand persistency) are supported
    * Support for PUPMODE 13 with periodic saving is gone
* `pupsave` creates save files and folders
    * All save files use ext4 (without journaling)
    * If possible, save files are created as [sparse files](https://en.wikipedia.org/wiki/Sparse_file), to reduce writing to disk and retain usable free space
    * Both save files and folders support encryption, using [fscrypt](https://www.kernel.org/doc/html/latest/filesystems/fscrypt.html)
        * Encryption can be enabled only for specific directories (like the user's home directory)
    * The "first shutdown" prompt that offers the user to save is gone, to make non-persistent installations less annoying to use
* `save2flash` is much faster and writes less (see woof-code/rootfs-petbuilds/psnapcp)
    * Preallocates space when files grow
    * Only copies appended or modified blocks when files change

## SFSs

* SFSs don't need to be "queued" by the user for loading at boot time: the init script loads all SFSs under the partition root and `psubdir` if specified, under both the save partition and the boot partition
    * This allows loading of extra SFSs without persistency
    * This removes Puppy's arbitrary limitation on the number and names of automatically-loadeded SFSs
    * SFSs are sorted numerically before loading, so 2something.sfs is loaded before 10something.sfs
        * The user controls the stacking order
        * The stacking order of the traditional *drv SFS is retained, for backward compatibility with Puppy
* Copying to RAM → locking in page cache
    * Copying of SFSs to a ramdisk (`pfix=ram|copy` or automatic) is gone and SFSs are locked in page cache instead (see woof-code/rootfs-petbuilds/sfslock)
        * This increases free ramdisk space under PUPMODE 13
        * The RAM occupied by cached SFSs is freed automatically (using [PSI](https://docs.kernel.org/accounting/psi.html) or OOM score adjustment) if needed
    * Copying is enabled automatically only if Puppy files reside on storage that doesn't support TRIM and assumed to be a slow device, like a flash drive
    * SFSs are prioritized and lower priority SFSs are not cached when cached SFSs occupy half of available RAM
    * This caching happens in the background while the boot process continues
* Built-in SFSs use [EROFS](https://docs.kernel.org/filesystems/erofs.html)
    * [Squashfs](https://docs.kernel.org/filesystems/squashfs.html) is supported as an alternative
* The devx SFS is gone

## Security

* Like Puppy, the operating system is designed for use by a single human user, but the desktop environment runs as an unprivileged user
    * Applications that want to run as root ask for user's approval
* Common sysfs hardening recommendations are applied out of the box
* The pup-advert-blocker ad blocking tool is reimplemented using a [NSS module](https://www.gnu.org/software/libc/manual/html_node/Name-Service-Switch.html)
    * It checks whether or not a domain should be blocked using binary search on a sorted array of [xxHash](https://github.com/Cyan4973/xxHash) hashes, instead of appending MBs of text to /etc/hosts and later scanning it line by line (see woof-code/rootfs-petbuilds/pup_advert_blocker)
* Improved firewall_ng
    * Enabled by default
    * Ported to [nftables](https://netfilter.org/projects/nftables)
    * Simplified: it produces a short list of rules what describe packets to accept, instead of explictly blocking many kinds of packets and accepting anything else
    * No longer does things that make sense on a router or a server, but don't do anything in an endpoint
    * Blocks mDNS, SSDP and NAT-PMP (both incoming and outgoing) by default, to mitigate vulnerabilities that can be triggered remotely through service discovery or port forwarding, and prevent leak of device information
* The MAC address is randomized when a network interface is brought up for the first time, to reduce device and user fingerprintability but without breaking things like DHCP reservations

# Directory Structure

* initrd-progs/ contains the initramfs skeleton
    * 0initrd/init is the early init script: it sets up an `overlay` file system and `switch_root`s into it
* kernel-kit/ contains a tool that builds the kernel
* woof-distro/x86_64/debian/trixie64/ contains configuration files
    * A [Debian](https://www.debian.org/) 13 based distro, featuring
        * [labwc](https://labwc.github.io/) with [waybar](https://github.com/Alexays/Waybar), or
        * [dwl](https://codeberg.org/dwl/dwl) with the [snail layout](https://codeberg.org/dwl/dwl-patches/src/branch/main/patches/snail) and [yambar](https://codeberg.org/dnkl/yambar)
    * DISTRO_SPECS contains the distro name and version
    * DISTRO_PKGS_SPECS-debian-testing contains a list of binary packages to include
    * _00build.conf contains a list of packages to build from source (`PETBUILDS`) and other settings
* woof-code/rootfs-skeleton contains the root file system skeleton
* woof-code/rootfs-packages contains optional additions to rootfs-skeleton
* woof-code/rootfs-petbuilds contains recipes for building packages from source
* woof-code/1download prepares a build environment
* woof-code/2buildkernel builds the kernel
* woof-code/3builddistro builds the packages specified in `PETBUILDS`, then packs everything together and builds bootable images

# Usage

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
