if [ -z "$WOOF_CFLAGS"]; then
    case "$DISTRO_TARGETARCH" in
    arm) WOOF_CFLAGS="-march=armv7-a -mfpu=neon-vfpv4 -mfloat-abi=hard" ;;
    x86) WOOF_CFLAGS="-march=i686 -mtune=i686" ;;
    x86_64) WOOF_CFLAGS="-march=x86-64 -mtune=generic" ;;
    esac
fi

[ -z "$WOOF_CXXFLAGS"] && WOOF_CXXFLAGS="$WOOF_CFLAGS"

WOOF_CC="/usr/bin/ccache gcc"
WOOF_CXX="/usr/bin/ccache g++"

WOOF_CFLAGS="$WOOF_CFLAGS -O2 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants"
WOOF_CXXFLAGS="$WOOF_CXXFLAGS -O2 -fomit-frame-pointer -ffunction-sections -fdata-sections -fmerge-all-constants"
WOOF_LDFLAGS="$WOOF_LDFLAGS -Wl,--gc-sections -Wl,--sort-common -Wl,-s"

MAKEFLAGS=-j`nproc`

HAVE_ROOTFS=0
HAVE_BUSYBOX=0

CHROOT_PFIX=
if [ "`uname -m`" = "x86_64" -a "$DISTRO_TARGETARCH" = "x86" ]; then
    echo "Simulating a 32-bit kernel"
    CHROOT_PFIX=linux32
fi

if [ -z "$PETBUILD_GTK" ]; then
    echo "WARNING: PETBUILD_GTK is empty, this may be a hard error in the future"
    [ -n "$GITHUB_ACTIONS" ] && exit 1

    PETBUILD_GTK=2
    if [ "$DISTRO_TARGETARCH" = "x86" ]; then
        echo "Using GTK+ 2 for x86 petbuilds"
    else
        GTK3_PC=`find ../packages-${DISTRO_FILE_PREFIX} -name gtk+-3.0.pc | head -n 1`
        if [ -n "$GTK3_PC" ]; then
            GTK3_VER=`awk '/Version:/{print $2}' "${GTK3_PC}"`
            vercmp "$GTK3_VER" ge 3.24.18
            if [ $? -eq 0 ]; then
                echo "Using GTK+ 3 for petbuilds"
                PETBUILD_GTK=3
            else
                echo "Using GTK+ 2 for petbuilds, GTK+ 3 is too old"
            fi
        else
            echo "Using GTK+ 2 for petbuilds, GTK+ 3 is missing"
        fi
    fi
fi

HERE=`pwd`
PKGS=

for NAME in $PETBUILDS; do
    HASH=`cat ../DISTRO_PKGS_SPECS-${DISTRO_BINARY_COMPAT}-${DISTRO_COMPAT_VERSION} ../rootfs-petbuilds/${NAME}/petbuild 2>/dev/null | md5sum | awk '{print $1}'`
    if [ ! -d "../petbuild-output/${NAME}-${HASH}" ]; then
        if [ $HAVE_ROOTFS -eq 0 ]; then
            echo "Preparing build environment"
            rm -rf petbuild-rootfs-complete
            cp -a rootfs-complete petbuild-rootfs-complete

            rm -f petbuild-rootfs-complete/bin/sh
            ln -s bash petbuild-rootfs-complete/bin/sh

            # these can be skipped, rc.update generates this cache
            for PROG in update-mime-database gtk-update-icon-cache glib-compile-schemas; do
                rm -f petbuild-rootfs-complete/usr/bin/$PROG
                cat << EOF > petbuild-rootfs-complete/usr/bin/$PROG
#!/bin/sh
echo "Skipping $PROG"
EOF
                chmod 755 petbuild-rootfs-complete/usr/bin/$PROG
            done

            cp -f /etc/resolv.conf petbuild-rootfs-complete/etc/
            cp -f ../packages-templates/ca-certificates/pinstall.sh petbuild-rootfs-complete/
            # required for void
            chroot petbuild-rootfs-complete ldconfig
            chroot petbuild-rootfs-complete sh /pinstall.sh
            rm -f petbuild-rootfs-complete/pinstall.sh

            # required for slacko
            chroot petbuild-rootfs-complete ldconfig

            # the shared-mime-info PET used by fossa64 doesn't put its pkg-config file in /usr/lib/x86_64-linux-gnu/pkgconfig
            PKG_CONFIG_PATH=`dirname $(find petbuild-rootfs-complete devx -name '*.pc' 2>/dev/null) 2>/dev/null | sed -e s/^petbuild-rootfs-complete//g -e s/^devx//g | sort | uniq | tr '\n' :`

            HAVE_ROOTFS=1
        fi

        echo "Downloading ${NAME}"

        mkdir -p ../petbuild-sources/${NAME}
        cd ../petbuild-sources/${NAME}
        . ${HERE}/../rootfs-petbuilds/${NAME}/petbuild
        download
        if [ -f ${HERE}/../rootfs-petbuilds/${NAME}/sha256.sum ]; then
            sha256sum -c ${HERE}/../rootfs-petbuilds/${NAME}/sha256.sum
            if [ $? -ne 0 ]; then
                rm -f ../petbuild-sources/${NAME}/* 2>/dev/null
                exit 1
            fi
        fi

        echo "Building ${NAME}"

        cd $HERE

        rm -rf ../petbuild-output/${NAME}-* # remove older petbuilds of $NAME
        mkdir -p ../petbuild-output/${NAME}-${HASH} petbuild-rootfs-complete-${NAME}
        LOWERDIR='devx:petbuild-rootfs-complete'
        mkdir petbuild-workdir
        mount -t overlay -o upperdir=../petbuild-output/${NAME}-${HASH},lowerdir=${LOWERDIR},workdir=petbuild-workdir petbuild petbuild-rootfs-complete-${NAME}

        mkdir -p petbuild-rootfs-complete-${NAME}/proc petbuild-rootfs-complete-${NAME}/sys petbuild-rootfs-complete-${NAME}/dev petbuild-rootfs-complete-${NAME}/tmp
        mkdir -p petbuild-rootfs-complete-${NAME}/root/.ccache petbuild-rootfs-complete-${NAME}/root/.cache
        mount --bind /proc petbuild-rootfs-complete-${NAME}/proc
        mount --bind /sys petbuild-rootfs-complete-${NAME}/sys
        mount --bind /dev petbuild-rootfs-complete-${NAME}/dev
        mount -t tmpfs -o size=1G petbuild-tmp-${NAME} petbuild-rootfs-complete-${NAME}/tmp
        mkdir -p ../petbuild-cache/.ccache
        mount --bind ../petbuild-cache/.ccache petbuild-rootfs-complete-${NAME}/root/.ccache
        mkdir -p ../petbuild-cache/.cache
        mount --bind ../petbuild-cache/.cache petbuild-rootfs-complete-${NAME}/root/.cache

        cp -a ../petbuild-sources/${NAME}/* petbuild-rootfs-complete-${NAME}/tmp/
        cp -a ../rootfs-petbuilds/${NAME}/* petbuild-rootfs-complete-${NAME}/tmp/
        CC="$WOOF_CC" CXX="$WOOF_CXX" CFLAGS="$WOOF_CFLAGS" CXXFLAGS="$WOOF_CXXFLAGS" LDFLAGS="$WOOF_LDFLAGS" MAKEFLAGS="$MAKEFLAGS" CCACHE_DIR=/root/.ccache CCACHE_NOHASHDIR=1 PKG_CONFIG_PATH="$PKG_CONFIG_PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONPYCACHEPREFIX=/root/.cache/__pycache__ PETBUILD_GTK=$PETBUILD_GTK $CHROOT_PFIX chroot petbuild-rootfs-complete-${NAME} bash -ec "cd /tmp && . /etc/DISTRO_SPECS && . ./petbuild && build"
        ret=$?
        umount -l petbuild-rootfs-complete-${NAME}/root/.cache
        umount -l petbuild-rootfs-complete-${NAME}/root/.ccache
        umount -l petbuild-rootfs-complete-${NAME}/tmp
        umount -l petbuild-rootfs-complete-${NAME}/dev
        umount -l petbuild-rootfs-complete-${NAME}/sys
        umount -l petbuild-rootfs-complete-${NAME}/proc
        umount -l petbuild-rootfs-complete-${NAME}
        rmdir petbuild-rootfs-complete-${NAME}

        find ../petbuild-output/${NAME}-${HASH} -type c -delete
        rm -rf petbuild-workdir

        if [ $ret -ne 0 ]; then
            echo "ERROR: failed to build ${NAME}"
            rm -rf ../petbuild-output/${NAME}-${HASH}
            rm -rf petbuild-rootfs-complete
            exit 1
        fi

        rm -rf ../petbuild-output/${NAME}-${HASH}/root/.cache
        rm -rf ../petbuild-output/${NAME}-${HASH}/root/.ccache
        rm -rf ../petbuild-output/${NAME}-${HASH}/var/cache
        rm -rf ../petbuild-output/${NAME}-${HASH}/tmp
        rm -rf ../petbuild-output/${NAME}-${HASH}/run
        rm -rf ../petbuild-output/${NAME}-${HASH}/etc/ssl
        rm -f ../petbuild-output/${NAME}-${HASH}/etc/resolv.conf
        rm -f ../petbuild-output/${NAME}-${HASH}/etc/ld.so.cache
        rm -f ../petbuild-output/${NAME}-${HASH}/root/.wget-hsts

        rm -f ../petbuild-output/${NAME}-${HASH}/usr/share/icons/hicolor/icon-theme.cache
        rm -rf ../petbuild-output/${NAME}-${HASH}/usr/lib/python*
        rm -rf ../petbuild-output/${NAME}-${HASH}/lib/pkgconfig
        rm -rf ../petbuild-output/${NAME}-${HASH}/usr/lib/pkgconfig
        rm -rf ../petbuild-output/${NAME}-${HASH}/usr/share/pkgconfig
        rm -rf ../petbuild-output/${NAME}-${HASH}/usr/include

        find ../petbuild-output/${NAME}-${HASH} -name '.wh*' -delete
        find ../petbuild-output/${NAME}-${HASH} -name '*.a' -delete
        find ../petbuild-output/${NAME}-${HASH} -name '*.la' -delete

        case $DISTRO_BINARY_COMPAT in
        slackware64) # in slacko64, we move all shared libraries to lib64
            for LIBDIR in lib usr/lib; do
                [ ! -d ../petbuild-output/${NAME}-${HASH}/${LIBDIR} ] && continue
                mkdir -p ../petbuild-output/${NAME}-${HASH}/${LIBDIR}64
                for SO in `ls ../petbuild-output/${NAME}-${HASH}/${LIBDIR}/*.so* 2>/dev/null`; do
                    mv -f $SO ../petbuild-output/${NAME}-${HASH}/${LIBDIR}64/
                done
                if [ -d ../petbuild-output/${NAME}-${HASH}/${LIBDIR}/gio ]; then
                    mv -f ../petbuild-output/${NAME}-${HASH}/${LIBDIR}/gio ../petbuild-output/${NAME}-${HASH}/${LIBDIR}64/
                fi
                rmdir ../petbuild-output/${NAME}-${HASH}/${LIBDIR} 2>/dev/null
            done
            ;;

        raspbian|debian|devuan|ubuntu|trisquel) # in debian, we move all shared libraries to ARCHDIR, e.g. lib/arm-linux-gnueabihf
            for PFIX in "" /usr; do
                for LIBDIR in lib64 lib; do
                    [ ! -d ../petbuild-output/${NAME}-${HASH}${PFIX}/${LIBDIR} ] && continue
                    mkdir -p ../petbuild-output/${NAME}-${HASH}${PFIX}/lib/${ARCHDIR}
                    for SO in `ls ../petbuild-output/${NAME}-${HASH}${PFIX}/${LIBDIR}/*.so* 2>/dev/null`; do
                        mv -f $SO ../petbuild-output/${NAME}-${HASH}${PFIX}/lib/${ARCHDIR}/
                    done
                    if [ -d ../petbuild-output/${NAME}-${HASH}${PFIX}/${LIBDIR}/gio ]; then
                        mv -f ../petbuild-output/${NAME}-${HASH}${PFIX}/${LIBDIR}/gio ../petbuild-output/${NAME}-${HASH}${PFIX}/lib/${ARCHDIR}/
                    fi
                    rmdir ../petbuild-output/${NAME}-${HASH}${PFIX}/${LIBDIR}/${ARCHDIR} 2>/dev/null
                    rmdir ../petbuild-output/${NAME}-${HASH}${PFIX}/${LIBDIR} 2>/dev/null
                done
            done
            ;;
        esac

        rmdir ../petbuild-output/${NAME}-${HASH}/usr/share/* 2>/dev/null
        rmdir ../petbuild-output/${NAME}-${HASH}/usr/* 2>/dev/null
        rmdir ../petbuild-output/${NAME}-${HASH}/* 2>/dev/null

        find ../petbuild-output/${NAME}-${HASH} -type f | while read ELF; do
            strip --strip-all -R .note -R .comment ${ELF} 2>/dev/null
        done

        find ../petbuild-output/${NAME}-${HASH} -name '.git*' -delete
    fi

    rm -f ../petbuild-output/${NAME}-latest
    ln -s ${NAME}-${HASH} ../petbuild-output/${NAME}-latest

    PKGS="$PKGS $NAME"
done

[ $HAVE_ROOTFS -eq 1 ] && rm -rf petbuild-rootfs-complete

echo "Copying petbuilds to rootfs-complete"

for NAME in $PKGS; do
    cp -a ../petbuild-output/${NAME}-latest/* rootfs-complete/

    for EXTRAFILE in ../rootfs-petbuilds/${NAME}/*; do
        case "${EXTRAFILE##*/}" in
        petbuild|*.patch|sha256.sum|*-*|DOTconfig|*.c|*.h|README.md) ;;
        *) cp -a $EXTRAFILE rootfs-complete/
        esac
    done

    if [ -f rootfs-complete/pinstall.sh ]; then
        cd rootfs-complete
        bash pinstall.sh
        rm -f pinstall.sh
        cd ..
    fi
done

echo
