# Puppy Compatibility

## Boot Codes

In Puppy, the early boot process searches all partitions for Puppy files if `pmedia=cd` but `pupsfs` is not specified, and searches all partitions for save folders or files if `pmedia=cd` but `psave` is not specified. `pmedia=usbflash` also enables such searches, but only on USB devices.

Unlike Puppy, DISTRO_NAME always falls back to search on all partitions if needed. Specifying `pmedia` is not mandatory.

In addition, DISTRO_NAME does not support `pfix=fsckp`: `pfix=fsck` in DISTRO_NAME is equivalent to `pfix=fsck,fsckp` in Puppy. In other words, `pfix=fsck` enables file system error repair on all file systems mounted during the boot process and not only the file system inside the save file (if used).

## .pet Packages

DISTRO_NAME provides partial backward compatibility with old .pet packages, through petget. Many .pet packages are old and unmaintained: some even depend on [ROX-Filer](https://rox.sourceforge.net/desktop/ROX-Filer), [JWM](http://joewing.net/projects/jwm/) or [X.Org](https://www.x.org/).

To install a .pet package, open it using the file manager.

By default, petget is a hidden application without a menu entry until a .pet package is installed. To remove a .pet package, start petget through the menu entry, select a package and click Remove.

petget does not install missing dependencies automatically and does not verify package compatibility prior to installation.

petget does not provide easy means for search, download and creation of .pet packages.