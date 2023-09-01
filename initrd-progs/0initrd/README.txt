=========================================
                  /init
=========================================

The init script has been called the heart of Puppy Linux.
This is not because it implements a lot of Puppy stuff, but because this is where Puppy starts.
When init starts, the full-blown Puppy is still just a number of files on a storage device.
The job of init is to use those files to build a Puppy based in RAM and then hand over control to it.


Some significant files in the init world:
=========================================

vmlinuz:
   This is the Linux part of Puppy Linux, usually referred to as the Linux kernel.
   The boot process has already loaded this into memory and started running it before init starts.

initrd.gz:
   This contains the Puppy files that form the RAM based filesystem that is in place when init runs.
   The init script is one of these files.

The puppy sfs files, puppy...sfs, zdrv...sfs, fdrv...sfs, ydrv...sfs, adrv...sfs:
(Where ... is a particular puppy name and version, e.g. zdrv_slacko64_6.9.5.sfs)

puppy...sfs:
   This is the main Puppy file, containing most, if not all, the software that is in the current Puppy.
   This is the only sfs file that is required, if the init script cannot load it for any reason, the boot is abandoned.

zdrv...sfs:
   This contains kernel modules(device drivers), and firmware files matching the kernel in vmlinuz.
   Without this file, Puppy will usually still boot, but some devices will either not work or not work properly.

fdrv...sfs:
   This contains firmware files. It can be used to override the contents of zdrv...sfs.
   This file is present in only some Puppies.

bdrv...sfs:
   This contains a basic installation or skeleton of the compatible distro.
   With this file, more binary packages from the compatible distro repos are likely to work.
   It is usually not present.

ydrv...sfs:
   Notionally a patch file. It can be used to override the contents of puppy...sfs.
   It is usually not present.

adrv...sfs:
   Notionally an application file. It overrides the contents of all other sfs files.
   It is usually not present.


Overview of how it works:
=========================

* A typical frugal install of Puppy is a directory containing the above files.
* So init begins by establishing the location of this directory,
by looking for the puppy...sfs file.
* In the absence of any indication as to it's location, init searches throughout
the partitions of the system until it finds it.
* If it cannot locate the puppy...sfs file, it abandons the boot by dropping out to
a console with several error messages on the screen.
* Having located the puppy...sfs it proceeds to create a layered file system
from the sfs files in the directory.

* A layered filesystem consists of a stack of directories, most of these layers can be read-only,
but the top one is always read-write.
* The directory that contains the stack, appears to contain all the files from every layer.
* But if a file exists in more than one layer the one in the top-most layer is the one that is seen.
So the order of layers is significant.

* Init creates a stack containing only a directory in a RAM based tmpfs as the read-write layer.
* It then appends the puppy...sfs to this stack.
* It then processes the other sfs files, if they exist.
* It appends the fdrv...sfs.
* It appends the zdrv...sfs.
* It inserts the ydrv...sfs immediately below the read-write layer.
* It inserts the adrv...sfs immediately below the read-write layer.
* If all files are present we end up with a stack that looks like this:
tmpfs        read-write
adrv...sfs   read-only
ydrv...sfs   read-only
puppy...sfs  read-only
fdrv...sfs   read-only
zdrv...sfs   read-only

* If this is a first boot, the stack is ready to be made into the running system.
* But, this first boot stack contains no persistent storage.

* If you change any files in the running system they are written to the
read-write layer which only exists in RAM.

* The first time you reboot or shutdown, Puppy asks if you want to save the session.
* If you save the session you will be guided through a process to create a save layer,
to which Puppy will then copy any changed files.
* So, if this is not a first boot, init has to setup any save layer and insert it into the stack.

* Init attempts to sort out what type of save layer mechanism is being used, and make it available as a directory.
* If this attempt fails at any point, nothing extra will be done and the boot proceeds with the first boot stack.

* If the boot is considered to be from a "flash" device, the directory containing the save layer
is inserted as a read-only layer immediately below the read-write layer.
* Otherwise the tmpfs read-write layer is replaced with the directory
containing the save layer as the read-write layer.
* The stack is then made into the running system and init exits.

* If non-critical errors are detected by init it usually writes them to a file called bootinit.log
* bootinit.log also stores debug messages you might want to read.
* This file can be accessed in a running puppy as /initrd/tmp/bootinit.log


Things that provide input to init and change the things it does:
================================================================

DISTRO_SPECS:
   This is a file in initrd.gz that is created by the Puppy builder.
   It contains definitions of various information about a particular Puppy.
   DISTRO_FILE_PREFIX defines the name that occurs frequently in files that belong to it. e.g. 'slacko64'.
   DISTRO_VERSION defines the version number. e.g. '6.9.5'
   Very significant for init are DISTRO_PUPPYSFS, DISTRO_ZDRVSFS, DISTRO_FDRVSFS, DISTRO_YDRVSFS,
      DISTRO_ADRVSFS, which define the default filenames for each of the Puppy sfs files.


Boot parameters:
================

pmedia=<atahd|ataflash|usbhd|usbflash|cd> 
   Indicates the type of boot device.
   If it's "cd" then all partitions are searched for Puppy files and a save layer file.
   If the first 3 characters are "usb", then any searching is restricted to only usb devices.
   If the last 5 characters are "flash" the top layer in the stack remains the tmpfs in memory, otherwise any found save layer becomes the top layer in the stack.
   This boot parameter should always be provided.

psubdir=</path/to/install/directory>
   If the Puppy files are not in the root of a partition, but in a sub-directory, the path of this directory, relative to the partition root, must be specified with this parameter.
   e.g. If the sdb2 partition is mounted as /mnt/sdb2 and the Puppy files are in /mnt/sdb2/tahr64, then "psubdir=tahr64" or "psubdir=/tahr64" must be specified.
   This parameter can specify subdirectories at more that a single level, e.g. "psubdir=puppy/tahr64" or "psubdir=/puppy/tahr64".
   If a leading "/" is not provided, init will add it.
   This is the default path for locating any puppy file and any partition.

------------------------------------------------------------
pupsfs=<partition> Specifies the puppy...sfs partition
psave=<partition>  Specifies the save layer  partition

   Where <partition> is a partition uuid
       e.g. 0db94719-cdf1-44b7-9766-23db62fb85a5

   Specifying psave=<partition> can be quite useful in directing all save layers to a different partition.
       e.g. If your puppies reside on an ntfs partition,
       then you can get yourself a savefolder by creating a Linux partition on a usb stick or hd,
       and then specifying a psave=<the uuid of the Linux partition> boot parameter.
       If you forget to plug in the appropriate device, Puppy will simply do a first boot,
         no harm done, just insert the appropriate usb device and reboot.

    ex: psave=0db94719-cdf1-44b7-9766-23db62fb85a5
    ex: pupsfs=0db94719-cdf1-44b7-9766-23db62fb85a5

------------------------------------------------------------

pfix=<ram, nox, nocopy, fsck, fsckp, rdsh, <number>>
   The pfix parameter is a ',' separated list of 1 or more of the above sub-parameters.
   ram:      run in ram only (do not load ${DISTRO_FILE_PREFIX}save).
   nox:      do not start X.
   copy:     copy .sfs files into ram
   nocopy:   do not copy .sfs files into ram (default is copy if ram > 1024 MB, while free ramdisk space is >= 64 MB).
   fsck:     do fsck of ${DISTRO_FILE_PREFIX}save.?fs file.
   fsckp:    do fsck before first mount of supported partitions.
   rdsh:     exit to shell in initial ramdisk.
   <number>: blacklist last <number> folders (multisession). e.g. pfix=3


#############################
    MORE TECHNICAL NOTES
#############################

How the script determines what pupsave to use
=============================================

If you haven't specified psave=<partition> then init looks
for a file with this base name:

/DISTRO_SPECS -> DISTRO_FILE_PREFIX='...'

 ${DISTRO_FILE_PREFIX}save - is the fixed base name for all pupsave folders
 ${DISTRO_FILE_PREFIX}save.?fs - is the fixed base name for all pupsave files

