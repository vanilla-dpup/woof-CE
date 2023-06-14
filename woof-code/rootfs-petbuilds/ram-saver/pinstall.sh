echo `dirname $(chroot . ldd /bin/sh | grep libc.so.6 | cut -f 3 -d ' ')`/libramsaver.so.1 >> etc/ld.so.preload
