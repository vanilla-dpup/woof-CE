# Rebuilding DISTRO_NAME

DISTRO_NAME is capable of rebuilding itself: every DISTRO_NAME image contains the [woof-CE](woof-CE.md) build system used to produce it, under /usr/share/woof-CE. The build process requires a lot of disk space and can take many hours to complete.

First, install `debootstrap`:

```
apt update
apt install -y debootstrap
```

It is not recommended to run woof-CE under [PUPMODE](pupmode.md) 5 or 13 because ramdisk space is limited: if you can, extract the woof-CE tarball in a big partition, on a fast and reliable internal drive:

```
cd /mnt/home
tar -xJf /usr/share/woof-CE/woof-out_*.tar.xz
cd woof-out_*
```

Everything is configured to reproduce the running DISTRO_NAME version. You can customize DISTRO_SPECS, DISTRO_PKGS_SPECS-* and _00build.conf, add build recipes to rootfs-petbuilds or add extra scripts to rootfs-packages.

Once you're done tweaking the build system, download all required packages and create a build environment:

```
./1download
```

Then, build the kernel:

```
./2buildkernel
```

Finally, build applications and produce bootable images:

```
./3builddistro
```
