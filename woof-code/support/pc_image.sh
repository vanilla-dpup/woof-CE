BIOS_IMG_BASE=${DISTRO_FILE_PREFIX}-${DISTRO_VERSION}-ext4-2gb-bios.img
UEFI_IMG_BASE=${DISTRO_FILE_PREFIX}-${DISTRO_VERSION}-ext4-2gb-uefi.img

set -e

mount --bind /dev rootfs-complete/dev
mkdir rootfs-complete/build
mount --bind build rootfs-complete/build

echo "Building ${BIOS_IMG_BASE}"

dd if=/dev/zero of=${BIOS_IMG_BASE} bs=50M count=40 conv=sparse
LOOP=`losetup -f --show ${BIOS_IMG_BASE}`
chroot rootfs-complete bootflash ${LOOP#/dev/} syslinux ext4 /build
losetup -d ${LOOP}
mv -f ${BIOS_IMG_BASE} ../${WOOF_OUTPUT}/

if [ "$WOOF_TARGETARCH" = "x86_64" ]; then
	echo "Building ${UEFI_IMG_BASE}"

	dd if=/dev/zero of=${UEFI_IMG_BASE} bs=50M count=40 conv=sparse
	LOOP=`losetup -f --show ${UEFI_IMG_BASE}`
	chroot rootfs-complete bootflash ${LOOP#/dev/} efilinux ext4 /build
	losetup -d ${LOOP}

	mv -f ${UEFI_IMG_BASE} ../${WOOF_OUTPUT}/
fi

umount -l rootfs-complete/dev
umount -l rootfs-complete/build
rmdir rootfs-complete/build

set +e
