# woof - the Puppy builder

This is a fork of [woof-CE](https://github.com/puppylinux-woof-CE/woof-CE).

The goal is to build something similar to [DebianDog](https://debiandog.github.io/doglinux/), a highly [Debian](https://www.debian.org/)-compatible "live" distro with a layered file system, but with core features of [Puppy Linux](https://puppylinux.com), a distro that -
* Provides a lightweight desktop environment and a variety of applications, all built from source to minimize dependencies
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
* ISO images are gone: the woof-CE build output is a bootable flash drive image.
* Support for PUPMODEs other than 5 (live), 12 (automatic persistency) and 13 (on-demand persistency) is gone.
* Support PUPMODE 13 with periodic saving is gone. The user can run `save2flash` to save now, or save at shutdown.
* ntfs-3g is replaced with [ntfs3](https://www.kernel.org/doc/html/next/filesystems/ntfs3.html).
* Support for the devx SFS is gone. Development packages are installed inside a copy of the main SFS during the build, but don't make it into the build output.
* The Puppy way of doing things is replaced with the upstream distro way of doing things. For example, rc.country is gone, and so is the hack of exporting LANG in /etc/profile. Instead, one should use /etc/default/locale, /etc/locale.gen, locale-gen, etc'.
* Themes are gone. [Themes break applications](https://stopthemingmy.app/) and they're hard to maintain.
* coreutils, util-linux, etc' are not replaced with symlinks to busybox, because this breaks compatibility with the upstream distro.
* busybox init, /etc/inittab, plogin, autologin, etc' are replaced with a simple init implementation (see woof-code/rootfs-petbuilds/init).
* Legacy cruft is removed from the init script (/etc/rc.d/rc.sysinit) and it's much faster. Daemons like udev and dbus are started using their init scripts.
* Some core Puppy scripts that override the upstream distro are moved to /usr/local/{,s}bin and PATH makes the shell prefer them. This makes package updates safe, because they no longer remove Puppy's hooks.

Other changes:

* The prompt that asks whether or not to save at shutdown is now graphical, and the old terminal-based prompt is only used as fallback: for example, if the compositor crashed.
* All save files (including encrypted ones) use ext4, with or without journaling.
* Bootflash in upstream supports FAT32 and f2fs, using syslinux, extlinux or efilinux. This fork adds ext4 support.
* If possible, save files are created as [sparse files](https://en.wikipedia.org/wiki/Sparse_file), to reduce writing to disk and retain usable free space in the partition.

## Usage

	sudo apt-get install -y --no-install-recommends dc debootstrap librsvg2-bin zstd xml2 syslinux-utils extlinux

Then:

	./merge2out woof-distro/x86_64/debian/bookworm64

(Debian 12 based, featuring [dwl](https://github.com/djpohly/dwl) with the [snail layout](https://github.com/djpohly/dwl/wiki/snail))

Or:

	./merge2out woof-distro/x86_64/debian/trixie64

(Debian 13 based, featuring [labwc](https://labwc.github.io/) and [sfwbar](https://github.com/LBCrion/sfwbar))

Then:

	cd ../woof-out_*
	./1download
	./3builddistro

## Configuration Files

### /etc/environment

This file defines environment variables for the user's interactive shell and all descendant processes, including the compositor.

Among other things, this file defines the dwl background and window border color.

### ~/.libinputrc

This file defines input device (mouse and touchpad) settings.

For example, to enable left-handed mode:

	LIBINPUT_DEFAULT_LEFT_HANDED=1

### ~/.xkbrc

This file defines keyboard settings.

For example, to enable English and Hebrew with Alt+Shift to switch between the two:

	XKB_DEFAULT_LAYOUT=us,il
	XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle

### ~/.config/autostart/swayidle.desktop

This configures auto-start of swayidle, which turns off the screen after 600 seconds of inactivity.

You can disable swayidle by deleting this file, or change the interval via ~/.config/swayidle/config.

### ~/.config/autostart/swaybg.desktop

This configures auto-start of swaybg and defines the background color or image to display.

### /etc/init.d/trim

This script runs at boot time and implements periodic TRIM.

To disable it:

	chmod -x /etc/init.d/trim

### /etc/rc.d/rc.local

This script can be used to run extra initialization steps at the end of the boot process.

### /etc/eventmanager

This file determines whether or not to offer the user to save on shutdown, when using PUPMODE 13.

To disable the prompt and skip saving on shutdown:

	ASKTOSAVE=false

### ~/.dwlinitrc

This script runs as dwl's child process and handles application auto-start.

### /var/local/xwin_disable_xerrs_log_flag

Delete this file to enable logging of compositor errors to /tmp/xerrs.log.
