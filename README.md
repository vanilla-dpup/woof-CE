# woof - the Puppy builder

## Overview

This is a fork of [woof-CE](https://github.com/puppylinux-woof-CE/woof-CE) that strips woof-CE down to the bare essentials.

* Only dpup ([Debian](https://www.debian.org/) or [Devuan](https://www.devuan.org/) based Puppy) is supported.
* Support for X.Org and tools that modify xorg.conf are gone. Only Wayland is supported.
* Support for ROX-Filer is gone, and the "source of truth" regarding file associations and default applications is xdg-utils. /usr/local/bin/default* are provided for backward compatibility with Puppy.
* Most of 0setup, 1download, 2createpackages and 3builddistro is reimplemented using [debootstrap](https://wiki.debian.org/Debootstrap).
* PPM and support for .pet packages are gone: packages in the build come from rootfs-packages or rootfs-petbuilds (built from source).
* The only supported kind of kernel packages it the "huge" one.
* Support for aufs is gone.
* ISO images are gone: the woof-CE build output is a bootable flash drive image.
* Support for PUPMODEs other than 5 (live), 12 (automatic persistency) and 13 (on-demand persistency) is gone.
* All save files use ext4, with or without journaling.
* ntfs-3g is replaced with [ntfs3](https://www.kernel.org/doc/html/next/filesystems/ntfs3.html).
* If possible, save files are created as [sparse files](https://en.wikipedia.org/wiki/Sparse_file), to reduce writing to disk and retain usable free space in the partition.
* Support for the devx SFS is gone. Development packages are installed inside a copy of the main SFS during the build, but don't make it into the build output.
* The Puppy way of doing things is replaced with the upstream distro way of doing things. For example, rc.country no longer sets the locale using the hack of exporting LANG in /etc/profile. Instead, one should use /etc/default/locale, /etc/locale.gen, locale-gen, etc'.
* Themes are gone. [Themes break applications](https://stopthemingmy.app/) and they're hard to maintain.
* coreutils, util-linux, etc' are not replaced with symlinks to busybox, because this breaks compatibility with the upstream distro.
* busybox init, /etc/inittab, plogin, autologin, etc' are replaced with a simple init implementation (see woof-code/rootfs-petbuilds/init).
* Legacy cruft is removed from the init script (/etc/rc.d/rc.sysinit) and it's much faster. Daemons like udev and dbus are started using their init scripts.
* Some core Puppy scripts that override the upstream distro are moved to /usr/local{,s}bin and PATH makes the shell prefer them. This makes package updates safe, because they no longer remove Puppy's hooks.

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

### ~/.dwlinitrc

This script runs as dwl's child process and handles application auto-start.

### /var/local/xwin_disable_xerrs_log_flag

Delete this file to enable logging of compositor errors to /tmp/xerrs.log.
