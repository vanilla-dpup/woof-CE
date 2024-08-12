#!/bin/bash -e

generate_initrd() {
	rm -rf ZZ_initrd-expanded
	mkdir -p ZZ_initrd-expanded/{bin,lib}
	cp -rf 0initrd/* ZZ_initrd-expanded
	cd ZZ_initrd-expanded
	cp -aLf ../../sandbox3/rootfs-complete/lib*/*-linux-*/ld-linux-*.so.2 lib/
	for BIN in usr/bin/busybox usr/bin/lsblk usr/sbin/pfscrypt sbin/e2fsck sbin/fsck.f2fs sbin/fsck.fat usr/sbin/fsck.exfat sbin/resize2fs; do
		cp -af ../../sandbox3/rootfs-complete/${BIN} bin/
		for LIB in `chroot  ../../sandbox3/rootfs-complete ldd /${BIN} | awk '{print $3}'`; do
			cp -anLf ../../sandbox3/rootfs-complete${LIB} lib/
		done
	done
	for BIN in `chroot  ../../sandbox3/rootfs-complete busybox --list`; do
		ln -s busybox bin/${BIN}
	done

	cp -f ../DISTRO_SPECS .

	. ./DISTRO_SPECS
	case "$DISTRO_TARGETARCH" in *64) ln -s lib lib64 ;; esac

	chroot . busybox --help > /dev/null
	chroot . e2fsck -V 2>/dev/null
	chroot . fsck.fat --help 2>/dev/null

	find . | cpio -o -H newc > ../initrd
	cd ..
	zstd -19 -f initrd

	echo -e "\n***        INITRD: initrd.zst [${ARCH}]"
	echo -e "*** /DISTRO_SPECS: ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_TARGETARCH}"
}

generate_initrd
