#!/bin/bash -e

generate_initrd() {
	rm -rf ZZ_initrd-expanded
	mkdir -p ZZ_initrd-expanded/{bin,lib}
	cp -rf 0initrd/* ZZ_initrd-expanded
	cd ZZ_initrd-expanded
	cp -aLf ../../sandbox3/rootfs-complete/lib*/ld-linux-*.so.2 lib/
	for BIN in usr/bin/busybox sbin/cryptsetup sbin/e2fsck sbin/fsck.f2fs sbin/fsck.fat sbin/resize2fs; do
		cp -af ../../sandbox3/rootfs-complete/${BIN} bin/
		for LIB in `chroot  ../../sandbox3/rootfs-complete ldd /${BIN} | awk '{print $3}'`; do
			cp -anLf ../../sandbox3/rootfs-complete${LIB} lib/
		done
	done

	cp -f ../DISTRO_SPECS .
	[ -x ../init ] && cp -f ../init .

	. ./DISTRO_SPECS
	case "$DISTRO_TARGETARCH" in *64) ln -s lib lib64 ;; esac

	find . | cpio -o -H newc > ../initrd
	cd ..
	zstd -19 -f initrd

	echo -e "\n***        INITRD: initrd.zst [${ARCH}]"
	echo -e "*** /DISTRO_SPECS: ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_TARGETARCH}"
}

generate_initrd
