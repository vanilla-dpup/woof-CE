BIOS_IMG_BASE=${DISTRO_FILE_PREFIX}-${DISTRO_VERSION}-ext4-2gb-bios.img
UEFI_IMG_BASE=${DISTRO_FILE_PREFIX}-${DISTRO_VERSION}-ext4-2gb-uefi.img

set -e

mount --bind /dev rootfs-complete/dev
mount --bind /proc rootfs-complete/proc
mkdir rootfs-complete/build
mount --bind build rootfs-complete/build
mkdir rootfs-complete/initrd
ln -s / rootfs-complete/initrd/pup_ro2
cat << EOF > rootfs-complete/usr/local/bin/uname
#!/bin/sh

/bin/uname "\$@" | sed s/`uname -r`/`basename build/kbuild-*.sfs .sfs | cut -f 2 -d -`/g
EOF
chmod 755 rootfs-complete/usr/local/bin/uname

if [ "$DISTRO_TARGETARCH" = "x86_64" -o "$DISTRO_TARGETARCH" = "x86" ]; then
	echo "Building ${BIOS_IMG_BASE}"

	dd if=/dev/zero of=${BIOS_IMG_BASE} bs=50M count=40 conv=sparse
	LOOP=`losetup -f --show ${BIOS_IMG_BASE}`
	chroot rootfs-complete bootflash ${LOOP#/dev/} syslinux ext4 13 /build folder 0 2 woofwoof
	losetup -d ${LOOP}
	mv -f ${BIOS_IMG_BASE} ../${WOOF_OUTPUT}/
fi

if [ "$DISTRO_TARGETARCH" = "x86_64" -o "$DISTRO_TARGETARCH" = "arm64" ]; then
	echo "Building ${UEFI_IMG_BASE}"

	dd if=/dev/zero of=${UEFI_IMG_BASE} bs=50M count=40 conv=sparse
	LOOP=`losetup -f --show ${UEFI_IMG_BASE}`
	chroot rootfs-complete bootflash ${LOOP#/dev/} efilinux ext4 13 /build folder 0 2 woofwoof
	losetup -d ${LOOP}

	mv -f ${UEFI_IMG_BASE} ../${WOOF_OUTPUT}/
fi

rm -f rootfs-complete/usr/local/bin/uname
rm rootfs-complete/initrd/pup_ro2
rmdir rootfs-complete/initrd
umount -l rootfs-complete/build
rmdir rootfs-complete/build
umount -l rootfs-complete/proc
umount -l rootfs-complete/dev

set +e
