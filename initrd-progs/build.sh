#!/bin/bash -e

generate_initrd() {
	rm -rf ZZ_initrd-expanded
	mkdir -p ZZ_initrd-expanded/{bin,lib}
	cp -rf 0initrd/* ZZ_initrd-expanded
	cd ZZ_initrd-expanded
	cp -aLf /lib*/*-linux-*/ld-linux-*.so.2 lib/
	for BIN in usr/bin/busybox usr/bin/lsblk usr/local/sbin/pfscrypt sbin/e2fsck sbin/fsck.f2fs sbin/fsck.fat usr/sbin/fsck.exfat sbin/resize2fs; do
		cp -af /${BIN} bin/
		for LIB in `ldd /${BIN} | awk '{print $3}'`; do
			cp -anLf ${LIB} lib/
		done
	done
	for BIN in `busybox --list`; do
		ln -s busybox bin/${BIN}
	done

	cp -f /etc/DISTRO_SPECS .

	. ./DISTRO_SPECS
	case "$DISTRO_TARGETARCH" in *64) ln -s lib lib64 ;; esac

	chroot . busybox --help > /dev/null
	chroot . e2fsck -V 2>/dev/null
	chroot . fsck.fat --help 2>/dev/null

	find . | cpio -o -H newc | zstd -19 > ../initrd.zst
	cd ..
	rm -rf ZZ_initrd-expanded
}

generate_initrd
