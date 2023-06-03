# woof - the Puppy builder

This is a fork of [woof-CE](https://github.com/puppylinux-woof-CE/woof-CE) that strips woof-CE down to the bare essentials.

* Most of 0setup, 1download, 2createpackages and 3builddistro is reimplemented using [debootstrap](https://wiki.debian.org/Debootstrap).
* PPM and support for .pet packages are gone: packages in the build come from rootfs-packages or rootfs-petbuilds (built from source).
* Support for X.Org and tools that modify xorg.conf are gone.
* Support for ROX-Filer is gone, and the "source of truth" regarding file associations and default applications is xdg-utils.
* The only supported kind of kernel packages it the "huge" one.
* Support for aufs is gone.
* Support for PUPMODE 5 (live), 12 (automatic persistency) and 13 (on-demand persistency) only.
* Support for the devx SFS is gone. Development packages are installed inside a copy of the main SFS during the build, but don't make it into the build output.
* The Puppy way of doing things is replaced with the upstream distro way of doing things. For example, rc.country no longer sets the locale using the hack of exporting LANG in /etc/profile. Instead, one should use /etc/default/locale, /etc/locale.gen, locale-gen, etc'.
* Themes are gone. [Themes break applications](https://stopthemingmy.app/) and they're hard to maintain.
* coreutils, util-linux, etc' are not replaced with symlinks to busybox, because this breaks compatibility with the upstream distro.
* busybox init, /etc/inittab, plogin, autologin, etc' are replaced with a simple init implementation (see woof-code/rootfs-petbuilds/init).
* Legacy cruft is removed from the init script (/etc/rc.d/rc.sysinit) and it's much faster.
