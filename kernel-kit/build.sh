# originally by Iguleder - hacked to DEATH by 01micko
# see README
# Compile fatdog style kernel [v3+ - 3.10+ recommended].

. ../DISTRO_SPECS
. ../_00build.conf

## extract the kernel
echo "Extracting the kernel sources"
tar -xf /usr/src/linux-source-*.tar.xz || exit 1

cd linux-source-*

echo "Cleaning the kernel sources"
make clean
make mrproper
find . \( -name '*.orig' -o -name '*.rej' -o -name '*~' \) -delete

./scripts/kconfig/merge_config.sh /boot/config-* ../debian-diffconfigs/${DISTRO_COMPAT_VERSION}

make olddefconfig
if [ $? -ne 0 ] ; then
	make oldconfig || exit 1
fi

kernel_version="`grep -Em1 '^# Linux/.+ [0-9]+\.[0-9]+\.[0-9]+ Kernel Configuration$' .config | awk '{print $3}'`"

## we need the arch of the system being built
if grep -q 'CONFIG_X86_64=y' .config ; then
	karch=x86
elif grep -q 'CONFIG_X86_32=y' .config ; then
	karch=x86
else
	echo "Your arch is unsupported."
	exit 1
fi

echo "Compiling the kernel"
make -j`nproc` bzImage modules || exit 1

#---------------------------------------------------------------------

echo "Creating the kernel package"
make INSTALL_MOD_PATH=`pwd`/../output/linux_kernel-${kernel_version}/usr INSTALL_MOD_STRIP=1 modules_install
cp -f arch/x86/boot/bzImage ../output/vmlinuz-${kernel_version}
rm -f ../output/linux_kernel-${kernel_version}/usr/lib/modules/${kernel_version}/{build,source}
mkdir -p ../output/linux_kernel-${kernel_version}/boot
cp -f .config ../output/linux_kernel-${kernel_version}/boot/config-${kernel_version}
cp -f System.map ../output/linux_kernel-${kernel_version}/boot/System.map-${kernel_version}

echo "Cleaning the kernel sources"
make clean
make prepare

cd ..

KBUILD_DIR="kbuild-${kernel_version}"
mkdir -p ${KBUILD_DIR}/usr/src/${KBUILD_DIR}
./kbuild.sh linux-source-* ${KBUILD_DIR}/usr/src/${KBUILD_DIR} ${karch} || exit 1
mkdir -p ${KBUILD_DIR}/usr/lib/modules/${kernel_version}
ln -s ../../../src/${KBUILD_DIR} ${KBUILD_DIR}/usr/lib/modules/${kernel_version}/build
ln -s ../../../src/${KBUILD_DIR} ${KBUILD_DIR}/usr/lib/modules/${kernel_version}/source
mkfs.erofs ${SFSCOMP} output/${KBUILD_DIR}.sfs ${KBUILD_DIR} || exit 1
rm -rf ${KBUILD_DIR}

KERNEL_MODULES_SFS_NAME="kernel-modules-${kernel_version}.sfs"
mkfs.erofs ${SFSCOMP} output/${KERNEL_MODULES_SFS_NAME} output/linux_kernel-${kernel_version} || exit 1
rm -rf output/linux_kernel-${kernel_version}

echo "Done!"

### END ###
