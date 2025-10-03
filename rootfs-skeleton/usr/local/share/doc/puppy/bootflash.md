# Bootflash

Bootflash is the DISTRO_NAME installer.

It partitions the selected device, erasing all existing data on it, and creates two partitions: a small FAT32 partition and a large [ext4](https://www.kernel.org/doc/html/latest/admin-guide/ext4.html) or [f2fs](https://docs.kernel.org/filesystems/f2fs.html) partition. The first partition is used for the boot loader, either [syslinux](https://www.syslinux.org) or [efilinux](https://github.com/puppylinux-woof-CE/efilinux). DISTRO_NAME files are placed on the second partition.

After partitioning, Bootflash can create a save folder or file (like [pupsave](pupsave.md)) and adds [boot codes](boot-codes.md) to EFI/boot/efilinux.cfg or syslinux.cfg. In persistent installations, Bootflash sets `psave=` to speed up the boot process by disabling scanning of recognized partitions for save folders or files.

**DISTRO_NAME does not support Secure Boot.** To boot DISTRO_NAME on a computer with UEFI, either disable Secure Boot or enable "Legacy" boot and choose syslinux during installation with Bootflash.
