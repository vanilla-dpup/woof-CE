#!/bin/bash
# originally by Iguleder - hacked to DEATH by 01micko
# see README
# Compile fatdog style kernel [v3+ - 3.10+ recommended].

. ./build.conf || exit 1
. ./funcs.sh

# if we're also building a Puppy, takes its SFS compression parameters
if [ -f ../_00build.conf ] ; then
	. ../_00build.conf
	COMP=$SFSCOMP
fi

CWD=`pwd`
wget --help | grep -q '\--show-progress' && WGET_SHOW_PROGRESS='-q --show-progress'
WGET_OPT='--no-check-certificate '${WGET_SHOW_PROGRESS}

MWD=$(pwd)
if [ -n "$GITHUB_ACTIONS" ] ; then
	BUILD_LOG=/proc/self/fd/1
	log_msg()    { echo -e "$@" ; }
else
	BUILD_LOG=${MWD}/build.log
	log_msg()    { echo -e "$@" ; echo -e "$@" >> ${BUILD_LOG} ; }
fi
exit_error() { log_msg "$@"  ; exit 1 ; }

for i in $@ ; do
	case $i in
		clean) DO_CLEAN=1 ; break ;;
		auto) AUTO=yes ; shift ;;
		nopae) x86_disable_pae=yes ; shift ;; #funcs.sh
		pae)   x86_enable_pae=yes  ; shift ;; #funcs.sh
	esac
	# if a filename is specified on the command line it is assumed to be
	# an extra build config that will be used in addition to build.conf
	if [ -f "$i" ]; then
		. ./${i} || exit 1
		shift
	fi
done

if [ $DO_CLEAN ] ; then
	echo "Please wait..."
	rm -rf ./{kernel*,build.log*,linux-*} output/*
	echo "Cleaning complete"
	exit 0
fi

#- ./sources is a symlink to $LOCAL_REPOSITORIES/kernel-kit/sources
LOCAL_REPOSITORIES='../../local-repositories'
[ -d ../local-repositories ] && LOCAL_REPOSITORIES='../local-repositories'
LOCAL_REPOSITORIES=${LOCAL_REPOSITORIES}/kernel-kit
mkdir -p ${LOCAL_REPOSITORIES}/sources ${LOCAL_REPOSITORIES}/tools
[ -e sources ] || ln -sv ${LOCAL_REPOSITORIES}/sources sources
[ -e tools ] || ln -sv ${LOCAL_REPOSITORIES}/tools tools
LOCAL_REPOSITORIES=$(cd $LOCAL_REPOSITORIES ; pwd)
export LOCAL_REPOSITORIES
#-

## delete the previous log
[ -f build.log ] && rm -f build.log
[ -f build.log.tar.bz2 ] && mv -f build.log.${today}.tar.bz2

## Dependency check...
for app in git gcc make ; do
	$app --version >/dev/null 2>&1 || exit_error "\033[1;31m""$app is not installed""\033[0m"
done
which mksquashfs >/dev/null 2>&1 || exit_error "\033[1;30m""mksquashfs is not installed""\033[0m"
log_ver #funcs.sh
which cc >/dev/null 2>&1 || ln -sv $(which gcc) /usr/bin/cc

if [ "$AUTO" = "yes" ] ; then
	[ ! "$DOTconfig_file" -a ! "$USE_GIT_KERNEL_CONFIG" ] && exit_error "Must specify DOTconfig_file=<file> in build.conf"
fi

case $(uname -m) in
	i?86)   HOST_ARCH=x86 ;;
	x86_64) HOST_ARCH=x86_64 ;;
	arm*)   HOST_ARCH=arm ;;
	*)      HOST_ARCH=$(uname -m) ;;
esac

## determine number of jobs for make
if [ ! "$JOBS" ] ; then
	JOBS="-j$(nproc)"
fi
[ "$JOBS" ] && log_msg "Jobs for make: ${JOBS#-j}" && echo

#------------------------------------------------------------------

if [ "$DOTconfig_file" -a ! -f "$DOTconfig_file" ] ; then
	exit_error "File not found: $DOTconfig_file (see build.conf - DOTconfig_file=)"
fi

if [ -f "$DOTconfig_file" ] ; then
	CONFIGS_DIR=${DOTconfig_file%/*} #dirname  $DOTconfig_file
	Choice=${DOTconfig_file##*/}     #basename $DOTconfig_file
	[ "$CONFIGS_DIR" = "$Choice" ] && CONFIGS_DIR=.
elif [ "$USE_GIT_KERNEL_CONFIG" ]; then
	Choice=USE_GIT_KERNEL_CONFIG
else
	[ "$AUTO" = "yes" ] && exit_error "Must specify DOTconfig_file=<file> in build.conf"
	## .configs
	[ -f /tmp/kernel_configs ] && rm -f /tmp/kernel_configs
	## CONFIG_DIR

	CONFIGS_DIR=configs_${HOST_ARCH}
	CONFIGS=$(ls ./${CONFIGS_DIR}/DOTconfig* 2>/dev/null | sed 's|.*/||' | sort -n)
	## list
	echo
	echo "Select the config file you want to use"
	NUM=1
	for C in $CONFIGS ;do
		echo "${NUM}. $C" >> /tmp/kernel_configs
		NUM=$(($NUM + 1))
	done
	if [ -f DOTconfig ] ; then
		echo "d. Default - current DOTconfig (./DOTconfig)" >> /tmp/kernel_configs
	fi
	echo "n. New DOTconfig" >> /tmp/kernel_configs
	cat /tmp/kernel_configs
	echo -n "Enter choice: " ; read Chosen
	[ ! "$Chosen" -a ! -f DOTconfig ] && exit_error "\033[1;31m""ERROR: invalid choice, start again!""\033[0m"
	if [ "$Chosen" ] ; then
		Choice=$(grep "^$Chosen\." /tmp/kernel_configs | cut -d ' ' -f2)
		[ ! "$Choice" ] && exit_error "\033[1;31m""ERROR: your choice is not sane ..quiting""\033[0m"
	else
		Choice=Default
	fi
	echo -en "\nYou chose $Choice. 
If this is ok hit ENTER, if not hit CTRL|C to quit: " 
	read oknow
fi

case $Choice in
	Default)
		kver=$(grep 'kernel_version=' DOTconfig | head -1 | tr -s ' ' | cut -d '=' -f2)
		if [ "$kver" = "" ] ; then
			if [ "$kernel_ver" = "" ] ; then
				echo -n "Enter kernel version for DOTconfig: "
				read kernel_version
				[ ! $kernel_version ] && echo "ERROR" && exit 1
				echo "kernel_version=${kernel_version}" >> DOTconfig
			else
				kernel_version=${kernel_ver} #build.conf
			fi
		fi
		;;
	New)
		rm -f DOTconfig
		echo -n "Enter kernel version (ex: 3.14.73) : "
		read kernel_version
		;;
	USE_GIT_KERNEL_CONFIG)
		# do nothing
		;;
	*)
		case "$Choice" in DOTconfig-*)
			IFS="-" read dconf kernel_version kernel_version_info <<< "$Choice" ;;
			*) kernel_version="" ;;
		esac
		if [ ! "$kernel_version" ] ; then
			kver=$(grep 'kernel_version=' ${CONFIGS_DIR}/$Choice | head -1 | tr -s ' ' | cut -d '=' -f2)
			sed -i '/^kernel_version/d' ${CONFIGS_DIR}/$Choice
			kernel_version=${kver}
			[ "$kernel_ver" ] && kernel_version=${kernel_ver} #build.conf
			if [ "$kernel_version" ] ; then
				echo "kernel_version=${kernel_version}" >> DOTconfig
				echo "kernel_version_info=${kernel_version_info}" >> DOTconfig
			else
				[ "$AUTO" = "yes" ] && exit_error "Must specify kernel_ver=<version> in build.conf"
			fi
		fi
		if [ "${CONFIGS_DIR}/$Choice" != "./DOTconfig" ] ; then
			cp -afv ${CONFIGS_DIR}/$Choice DOTconfig
		fi
		[ ! "$package_name_suffix" ] && package_name_suffix=${kinfo}
		;;
esac

if [ "$USE_GIT_KERNEL" ] ; then
	kernel_git_dir="`expr match "$USE_GIT_KERNEL" '.*/\([^/]*/[^/]*\)' | sed 's\/\_\'`"_git
	get_git_kernel # from funcs.sh
	kernel_version="`print_git_kernel_version`" # from funcs.sh

	if [ "$USE_GIT_KERNEL_CONFIG" ]; then
		configure_git_kernel # from funcs.sh
	fi
elif [ "$USE_STABLE_KERNEL" ]; then
	get_stable_kernel # from funcs.sh
	kernel_version="`print_git_kernel_version $STABLE_KERNEL_DIR`" # from funcs.sh
	if [ "$USE_GIT_KERNEL_CONFIG" ]; then
		configure_git_kernel $STABLE_KERNEL_DIR # from funcs.sh
	fi
fi
log_msg "kernel_version=${kernel_version}"
log_msg "kernel_version_info=${kernel_version_info}"
case "$kernel_version" in
	3.*|4.*|5.*|6.*) ok=1 ;; #----
	*) exit_error "ERROR: Unsupported kernel version" ;;
esac

if [ "$Choice" != "New" -a ! -f DOTconfig ] ; then
	exit_error "\033[1;31m""ERROR: No DOTconfig found ..quiting""\033[0m"
fi

export kernel_version
#------------------------------------------------------------------

# $package_name_suffix $custom_suffix $kernel_ver
[ ! "$kernel_mirrors" ] && kernel_mirrors="https://www.kernel.org/pub/linux/kernel"
ksubdir_3=v3.x #http://www.kernel.org/pub/linux/kernel/v3.x
ksubdir_4=v4.x
ksubdir_5=v5.x
ksubdir_6=v6.x
#-- random kernel mirror first
rn=$(( ( RANDOM % $(echo "$kernel_mirrors" | wc -l) )  + 1 ))
x=0
for i in $kernel_mirrors ; do
	x=$((x+1))
	[ $x -eq $rn ] && first="$i" && continue
	km="$km $i"
done
kernel_mirrors="$first $km"
#--

if [ -f /etc/DISTRO_SPECS ] ; then
	. /etc/DISTRO_SPECS
	[ ! "$package_name_suffix" ] && package_name_suffix=${DISTRO_FILE_PREFIX}
fi

if [ -f DOTconfig ] ; then
	echo ; tail -n10 README ; echo
	BUILTINS="CONFIG_NLS_CODEPAGE_850=y"
	vercmp ${kernel_version} ge 3.18 && BUILTINS="$BUILTINS CONFIG_OVERLAY_FS=y"
	for i in $BUILTINS
	do
		grep -q "$i" DOTconfig && { echo "$i is ok" ; continue ; }
		echo -e "\033[1;31m""\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!   WARNING     !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n""\033[0m"
		if [ "$i" = "CONFIG_OVERLAY_FS=y" ] ; then
			log_msg "For your kernel to boot overlay as a built in is required:"
			fs_msg="File systems -> Overlay filesystem support"
		else
			log_msg "For NLS to work at boot some configs are required:"
			fs_msg="NLS Support"
		fi
		echo "$i"
		echo "$i"|grep -q "CONFIG_NLS_CODEPAGE_850=y" && echo "CONFIG_NLS_CODEPAGE_852=y"
		log_msg "Make sure you enable this when you are given the opportunity after
	the kernel has downloaded and been patched.
	Look under ' $fs_msg'
	"
		[ -n "$GITHUB_ACTIONS" ] && exit 1
		[ "$AUTO" != "yes" ] && echo -n "PRESS ENTER" && read zzz
	done
fi

## fail-safe switch in case someone clicks the script in ROX (real story! not fun at all!!!!) :p
echo
[ "$AUTO" != "yes" ] && read -p "Press ENTER to begin" dummy

#------------------------------------------------------------------

## version info
IFS=. read -r kernel_series kernel_major_version kernel_minor_version <<< "${kernel_version}"

kernel_branch=${kernel_major_version} #3.x 4.x kernels
kernel_major_version=${kernel_series}.${kernel_major_version} #crazy!! 3.14 2.6 etc
if [ "$kernel_minor_version" ] ; then
	kmv=.${kernel_minor_version}
	kernel_tarball_version=${kernel_version}
else
	#single numbered kernel
	kmv=".0"
	kernel_version=${kernel_major_version}${kmv}
	kernel_tarball_version=${kernel_major_version}
	FIX_KERNEL_VER=yes
fi
[ "$kernel_minor_revision" ] && kmr=.${kernel_minor_revision}

log_msg "Linux: ${kernel_major_version}${kmv}${kmr}" #${kernel_series}.

# ===============================

package_version=${kernel_version}

# ===============================
#kernel mirror
case $kernel_series in
	3) ksubdir=${ksubdir_3} ;;
	4) ksubdir=${ksubdir_4} ;;
	5) ksubdir=${ksubdir_5} ;;
	6) ksubdir=${ksubdir_6} ;;
esac

## create directories for the results
rm -rf output/patches-${kernel_version}-${HOST_ARCH}
[ ! -d sources/kernels ] && mkdir -p sources/kernels
[ ! -d output/patches-${kernel_version}-${HOST_ARCH} ] && mkdir -p output/patches-${kernel_version}-${HOST_ARCH}
[ ! -d output ] && mkdir -p output

## get today's date
today=`date +%d%m%y`

#==============================================================
#    download kernel
#==============================================================

## download the kernel
testing=
echo ${kernel_version##*-} | grep -q "rc" && testing=/testing

DOWNLOAD_KERNEL=1
if [ -f sources/kernels/linux-${kernel_tarball_version}.tar.xz ] ; then
	DOWNLOAD_KERNEL=0
fi
if [ -f sources/kernels/linux-${kernel_tarball_version}.tar.xz.md5.txt ] ; then
	cd sources/kernels
	md5sum -c linux-${kernel_tarball_version}.tar.xz.md5.txt
	if [ $? -ne 0 ] ; then
		log_msg "md5sum FAILED: will resume kernel download..."
		DOWNLOAD_KERNEL=1
	fi
	cd $MWD
elif [ "$USE_MAINLINE_KERNEL_PLUS_PATCH" = "yes" ] ; then
	download_mainline_kernel_plus_patch # from funcs.sh
	DOWNLOAD_KERNEL=0
elif [ "$USE_GIT_KERNEL" ] ; then
	DOWNLOAD_KERNEL=0
elif [ "$USE_STABLE_KERNEL" ] ; then
	DOWNLOAD_KERNEL=0
else
	DOWNLOAD_KERNEL=1
fi

if [ $DOWNLOAD_KERNEL -eq 1 ] ; then
	KERROR=1
	for kernel_mirror in $kernel_mirrors ; do
		kernel_mirror=${kernel_mirror}/${ksubdir}
		log_msg "Downloading: ${kernel_mirror}${testing}/linux-${kernel_tarball_version}.tar.xz"
		wget ${WGET_OPT} -c -P sources/kernels ${kernel_mirror}${testing}/linux-${kernel_tarball_version}.tar.xz >> ${BUILD_LOG}
		if [ $? -ne 0 ] ; then
			echo "Error"
		else
			KERROR=
			break
		fi
	done
	[ $KERROR ] && exit 1
	cd sources/kernels
	md5sum linux-${kernel_tarball_version}.tar.xz > linux-${kernel_tarball_version}.tar.xz.md5.txt
	sha256sum linux-${kernel_tarball_version}.tar.xz > linux-${kernel_tarball_version}.tar.xz.sha256.txt
	cd $MWD
fi

## check if kernel supports gcc version
if [ -f linux-${kernel_version}/include/linux/compiler-gcc4.h ] ; then
	# it's one of the releases that provide gcc support through
	#    compiler-gcc3.h / compiler-gcc4.h / compiler-gcc5.h / etc
	# some patched versions or kernels 4.2+ only have this file: compiler-gcc.h
	gccver=$(gcc -dumpversion)
	gccver=${gccver%%.*}
	if [ "$gccver" -a ! -f linux-${kernel_version}/include/linux/compiler-gcc${gccver}.h ] ; then
		exit_error "Sorry, linux-${kernel_version} does not support gcc $gccver"
	fi
fi

#echo "HOST_ARCH = $HOST_ARCH"
if [ "$HOST_ARCH" = "x86" -a "$USE_GIT_X86_TOOLS" ]; then
	tools_git_dir="`expr match "$USE_GIT_X86_TOOLS" '.*/\([^/]*/[^/]*\)' | sed 's\/\_\'`"_git
	get_git_cross_compiler "$USE_GIT_X86_TOOLS" # from funcs.sh
	export PATH="${MWD}/tools/${tools_git_dir}/bin:$PATH"
elif [ "$HOST_ARCH" = "x86_64" -a "$USE_GIT_X86_64_TOOLS" ]; then
	tools_git_dir="`expr match "$USE_GIT_X86_64_TOOLS" '.*/\([^/]*/[^/]*\)' | sed 's\/\_\'`"_git
	get_git_cross_compiler "$USE_GIT_X86_64_TOOLS" # from funcs.sh
	export PATH="${MWD}/tools/${tools_git_dir}/bin:$PATH"
fi

#==============================================================
#                    compile the kernel
#==============================================================

## extract the kernel
log_msg "Extracting the kernel sources"
if [ "$USE_GIT_KERNEL" ] ; then
	rm -rf linux-${kernel_version}
	cp -a sources/${kernel_git_dir} linux-${kernel_version}
elif [ "$USE_STABLE_KERNEL" ] ; then
	rm -rf linux-${kernel_version}
	cp -a sources/${STABLE_KERNEL_DIR} linux-${kernel_version}
elif [ "$USE_MAINLINE_KERNEL_PLUS_PATCH" = "yes" ] ; then
	rm -rf linux-${kernel_version}
	mkdir linux-${kernel_version}
	cd linux-${kernel_version}
	tar --strip-components=1 -xf ../sources/kernels/linux-${kernel_major_version}.tar.xz >> ${BUILD_LOG} 2>&1
	[ $? -ne 0 ] && exit_error "ERROR extracting kernel sources."
	unxz -dc ../sources/kernels/patch-${kernel_tarball_version}.xz | patch -s -p1
	[ $? -ne 0 ] && exit_error "ERROR patching kernel sources."
	cd ..
else
	tar -xf sources/kernels/linux-${kernel_tarball_version}.tar.xz >> ${BUILD_LOG} 2>&1
fi
if [ $? -ne 0 ] ; then
	rm -f sources/kernels/linux-${kernel_tarball_version}.tar.xz
	exit_error "ERROR extracting kernel sources. file was deleted..."
fi

if [ "$FIX_KERNEL_VER" = "yes" ] ; then
	rm -rf linux-${kernel_version}
	mv -f linux-${kernel_tarball_version} linux-${kernel_version}
fi

#-------------------------
cd linux-${kernel_version}
#-------------------------

cp Makefile Makefile-orig
## custom suffix
if [ -n "${custom_suffix}" ] ; then
	sed -i "s/^EXTRAVERSION =.*/EXTRAVERSION = ${custom_suffix}/" Makefile
elif [ "$kernel_is_plus_version" = "yes" ]; then
	CONFIG_LOCALVERSION="`grep -F 'CONFIG_LOCALVERSION=' ../DOTconfig`"
	if [ "$CONFIG_LOCALVERSION" != "" ]; then
		local_version=${CONFIG_LOCALVERSION#CONFIG_LOCALVERSION=}
		local_version="${local_version//\"/}"
	fi
	# add the '+' to the suffix - 3, 4 versions
	case $kernel_series in
		3|4)custom_suffix="${local_version}+" ;;
		5)custom_suffix="${local_version}"    ;;
	esac
fi
diff -up Makefile-orig Makefile || diff -up Makefile-orig Makefile > ../output/patches-${kernel_version}-${HOST_ARCH}/version.patch
rm Makefile-orig

log_msg "Reducing the number of consoles and verbosity level"
for i in include/linux/printk.h kernel/printk/printk.c kernel/printk.c
do
	[ ! -f "$i" ] && continue
	z=$(echo "$i" | sed 's|/|_|g')
	cp ${i} ${i}.orig
	sed -i 's|#define CONSOLE_LOGLEVEL_DEFAULT .*|#define CONSOLE_LOGLEVEL_DEFAULT 3|' $i
	sed -i 's|#define DEFAULT_CONSOLE_LOGLEVEL .*|#define DEFAULT_CONSOLE_LOGLEVEL 3|' $i
	sed -i 's|#define MAX_CMDLINECONSOLES .*|#define MAX_CMDLINECONSOLES 5|' $i
	diff -q ${i}.orig ${i} >/dev/null 2>&1 || diff -up ${i}.orig ${i} > ../output/patches-${kernel_version}-${HOST_ARCH}/${z}.patch
done

for patch in ../patches/*.patch ../patches/${kernel_major_version}/*.patch ; do
	[ ! -f "$patch" ] && continue #../patches/ might not exist or it may be empty
	vercmp ${kernel_version} ge 4.14 && [ "$(basename "$patch")" = "commoncap-symbol.patch" ] && continue
	log_msg "Applying $patch"
	patch -p1 < $patch >> ${BUILD_LOG} 2>&1
	[ $? -ne 0 ] && exit_error "Error: failed to apply $patch on the kernel sources."
	cp $patch ../output/patches-${kernel_version}-${HOST_ARCH}
done

log_msg "Cleaning the kernel sources"
make clean
make mrproper
find . \( -name '*.orig' -o -name '*.rej' -o -name '*~' \) -delete

if [ -f ../DOTconfig ] ; then
	cp ../DOTconfig .config
	sed -i '/^kernel_version/d' .config
fi

#----
i386_specific_stuff #pae/nopae- funcs.sh
#----

[ -f .config -a ! -f ../DOTconfig ] && cp .config ../DOTconfig

# SET_MAKE_COMMAND is used for cross compiling ARM kernels
if [ "$SET_MAKE_COMMAND" ]; then
	export MAKE="$SET_MAKE_COMMAND"
else
	export MAKE='make'
fi

#####################
# pause to configure
function do_kernel_config() {
	log_msg "$MAKE $1"
	$MAKE $1 ##
	if [ $? -eq 0 ] ; then
		if [ -f .config -a "$AUTO" != "yes" ] ; then
			log_msg "\nOk, kernel is configured. hit ENTER to continue, CTRL+C to quit"
			read goon
		fi
	else
		exit 1
	fi
}

if [ "$AUTO" = "yes" ] ; then
	log_msg "$MAKE olddefconfig"
	$MAKE olddefconfig
	if [ "$?" != "0" ] ; then
		do_kernel_config oldconfig
	fi
else
	if [ -f .config ] ; then
		echo -en "
You now should configure your kernel. The supplied .config
should be already configured but you may want to make changes, plus
the date should be updated."
	else
		echo -en "\nYou must now configure the kernel"
	fi

	echo -en "
Hit a number or s to skip:
1. make menuconfig [default] (ncurses based)
2. make gconfig (gtk based gui)
3. make xconfig (qt based gui)
4. make oldconfig
s. skip

Enter option: " ; read kernelconfig
	case $kernelconfig in
		1) do_kernel_config menuconfig ;;
		2) do_kernel_config gconfig    ;;
		3) do_kernel_config xconfig    ;;
		4) do_kernel_config oldconfig   ;;
		s)
			log_msg "skipping configuration of kernel"
			echo "hit ENTER to continue, CTRL+C to quit"
			read goon
			;;
		*) do_kernel_config menuconfig ;;
	esac
fi

[ ! -f .config ] && exit_error "\nNo config file, exiting..."

#------------------------------------------------------------------

## we need the arch of the system being built
if grep -q 'CONFIG_X86_64=y' .config ; then
	arch=x86_64
	karch=x86
elif grep -q 'CONFIG_X86_32=y' .config ; then
	karch=x86
	if grep -q 'CONFIG_X86_32_SMP=y' .config ; then
		arch=i686
	else
		arch=i486 #gross assumption
	fi
elif grep -q 'CONFIG_ARM=y' .config ; then
	arch=arm
	karch=arm
else
	log_msg "Your arch is unsupported."
	arch=unknown #allow build anyway
	karch=arm
fi

#.....................................................................
if [ "$kit_kernel" = "yes" ]; then
	linux_kernel_dir=linux_kernel-${kernel_version}${custom_suffix}-${package_name_suffix}
else
	linux_kernel_dir=linux_kernel-${kernel_version}-${package_name_suffix}
fi
export linux_kernel_dir
#.....................................................................

## kernel headers
if [ "$kit_kernel" = "yes" ]; then
	kheaders_dir="kernel_headers-${kernel_version}${custom_suffix}-${package_name_suffix}-$arch"
else
	kheaders_dir="kernel_headers-${kernel_version}-${package_name_suffix}-$arch"
fi
rm -rf ../output/${kheaders_dir}
log_msg "Creating the kernel headers package"
$MAKE headers_check >> ${BUILD_LOG} 2>&1
$MAKE INSTALL_HDR_PATH=${kheaders_dir}/usr headers_install >> ${BUILD_LOG} 2>&1
find ${kheaders_dir}/usr/include \( -name .install -o -name ..install.cmd \) -delete
mv ${kheaders_dir} ../output

#------------------------------------------------------

# SET_MAKE_COMMAND is used for cross compiling ARM kernels
if [ "$SET_MAKE_COMMAND" ]; then
	export MAKE="$SET_MAKE_COMMAND"
else
	export MAKE='make'
fi
# SET_MAKE_TARGETS is used for compiling ARM kernels and dtbs
if [ "$SET_MAKE_TARGETS" ]; then
	export MAKE_TARGETS="$SET_MAKE_TARGETS"
else
	export MAKE_TARGETS="bzImage modules"
fi
echo "$MAKE ${JOBS} ${MAKE_TARGETS}
$MAKE INSTALL_MOD_PATH=${linux_kernel_dir}/usr INSTALL_MOD_STRIP=1 modules_install" > compile ## debug

log_msg "Compiling the kernel"
$MAKE ${JOBS} ${MAKE_TARGETS} >> ${BUILD_LOG} 2>&1
if [ "$kit_kernel" = "yes" ]; then
	KCONFIG="output/DOTconfig-${kernel_version}${custom_suffix}-${HOST_ARCH}-${today}"
else
	KCONFIG="output/DOTconfig-${kernel_version}-${HOST_ARCH}-${today}"
fi
cp .config ../${KCONFIG}

if [ "$karch" = "x86" ] ; then
	if [ ! -f arch/x86/boot/bzImage -o ! -f System.map ] ; then
		exit_error "Error: failed to compile the kernel sources."
	fi
else
	if [ ! -f arch/arm/boot/zImage ] ; then #needs work
		exit_error "Error: failed to compile the kernel sources."
	fi
fi

#---------------------------------------------------------------------

log_msg "Creating the kernel package"
$MAKE INSTALL_MOD_PATH=${linux_kernel_dir} INSTALL_MOD_STRIP=1 modules_install >> ${BUILD_LOG} 2>&1
rm -f ${linux_kernel_dir}/usr/lib/modules/${kernel_version}${custom_suffix}/{build,source}
mkdir -p ${linux_kernel_dir}/boot
mkdir -p ${linux_kernel_dir}/etc/modules
## /boot/config-$(uname -m)     ## http://www.h-online.com/open/features/Good-and-quick-kernel-configuration-creation-1403046.html
cp .config ${linux_kernel_dir}/boot/config-${kernel_version}${custom_suffix}
## /boot/Sytem.map-$(uname -r)  ## https://en.wikipedia.org/wiki/System.map
cp System.map ${linux_kernel_dir}/boot/System.map-${kernel_version}${custom_suffix}
## /etc/moodules/..
if [ "$kit_kernel" = "yes" ]; then
	cp .config ${linux_kernel_dir}/etc/modules/DOTconfig-${kernel_version}${custom_suffix}-${today}
else
	cp .config ${linux_kernel_dir}/etc/modules/DOTconfig-${kernel_version}-${today}
fi
for i in `find ${linux_kernel_dir}/usr/lib/modules -type f -name "modules.*"| grep -E 'order$|builtin$'`;do 
	cp $i ${linux_kernel_dir}/etc/modules/${i##*/}-${kernel_version}${custom_suffix}
	log_msg "copied ${i##*/} to ${linux_kernel_dir}/etc/modules/${i##*/}-${kernel_version}${custom_suffix}"
done

#cp arch/x86/boot/bzImage ${linux_kernel_dir}/boot/vmlinuz
IMAGE=`find . -type f -name bzImage | head -1`
if [ "$IMAGE" = "" ]; then
	#or cp arch/arm/boot/zImage ${linux_kernel_dir}/boot/vmlinuz
	IMAGE=`find . -type f -name zImage | head -1`
fi
cp ${IMAGE} ${linux_kernel_dir}/boot
cp ${IMAGE} ${linux_kernel_dir}/boot/vmlinuz

if [ "$karch" = "arm" ]; then
	BOOT_DIR="boot-${kernel_version}${custom_suffix}"
	mkdir -p ../output/${BOOT_DIR}/
	cp arch/arm/boot/dts/*.dtb ../output/${BOOT_DIR}/
	mkdir -p ../output/${BOOT_DIR}/overlays/
	cp arch/arm/boot/dts/overlays/*.dtb* ../output/${BOOT_DIR}/overlays/
	cp arch/arm/boot/dts/overlays/README ../output/${BOOT_DIR}/overlays/
else
	BOOT_DIR=""
fi

mv ${linux_kernel_dir} ../output ## ../output/${linux_kernel_dir}

## make fatdog kernel module package
if [ "$kit_kernel" = "yes" ]; then
	OUTPUT_VERSION="${package_version}${custom_suffix}-${package_name_suffix}"
else
	OUTPUT_VERSION="${package_version}-${package_name_suffix}"
fi
mv ../output/${linux_kernel_dir}/boot/vmlinuz \
	../output/vmlinuz-${OUTPUT_VERSION}
[ -f ../output/${linux_kernel_dir}/boot/bzImage ] && \
	rm -f ../output/${linux_kernel_dir}/boot/bzImage
[ -f ../output/${linux_kernel_dir}/boot/zImage ] && \
	rm -f ../output/${linux_kernel_dir}/boot/zImage
log_msg "${linux_kernel_dir} is ready in output"

log_msg "Cleaning the kernel sources"
make clean >> ${BUILD_LOG} 2>&1
$MAKE prepare >> ${BUILD_LOG} 2>&1

#----
cd ..
#----

if [ "$kit_kernel" = "yes" ]; then
	KERNEL_SOURCES_DIR="kernel_sources-${package_version}${custom_suffix}-${package_name_suffix}"
else
	KERNEL_SOURCES_DIR="kernel_sources-${package_version}-${package_name_suffix}"
fi
KBUILD_DIR="kbuild-${package_version}${custom_suffix}"
if [ "$CREATE_SOURCES_SFS" != "no" ]; then
	log_msg "Creating a kernel sources SFS"
	mkdir -p ${KERNEL_SOURCES_DIR}/usr/src
	mv linux-${kernel_version} ${KERNEL_SOURCES_DIR}/usr/src/linux
	KERNEL_MODULES_DIR=${KERNEL_SOURCES_DIR}/usr/lib/modules/${kernel_version}${custom_suffix}
	mkdir -p ${KERNEL_MODULES_DIR}
	ln -s ../../../src/linux ${KERNEL_MODULES_DIR}/build
	ln -s ../../../src/linux ${KERNEL_MODULES_DIR}/source
	if [ ! -f ${KERNEL_SOURCES_DIR}/usr/src/linux/include/linux/version.h ] ; then
		ln -s /usr/src/linux/include/generated/uapi/linux/version.h \
			${KERNEL_SOURCES_DIR}/usr/src/linux/include/linux/version.h
	fi
	rm -rf ${KERNEL_SOURCES_DIR}/usr/src/linux/.git* # don't need git history
	mksquashfs ${KERNEL_SOURCES_DIR} output/${KERNEL_SOURCES_DIR}.sfs $COMP
	md5sum output/${KERNEL_SOURCES_DIR}.sfs > output/${KERNEL_SOURCES_DIR}.sfs.md5.txt
	sha256sum output/${KERNEL_SOURCES_DIR}.sfs > output/${KERNEL_SOURCES_DIR}.sfs.sha256.txt

	if [ "$CREATE_KBUILD_SFS" = "yes" ]; then
		mkdir -p ${KBUILD_DIR}/usr/src/${KBUILD_DIR}
		./kbuild.sh ${KERNEL_SOURCES_DIR}/usr/src/linux ${KBUILD_DIR}/usr/src/${KBUILD_DIR} ${karch} || exit 1
		mkdir -p ${KBUILD_DIR}/usr/lib/modules/${kernel_version}${custom_suffix}
		ln -s ../../../src/${KBUILD_DIR} ${KBUILD_DIR}/usr/lib/modules/${kernel_version}${custom_suffix}/build
		ln -s ../../../src/${KBUILD_DIR} ${KBUILD_DIR}/usr/lib/modules/${kernel_version}${custom_suffix}/source
		[ -n "$GITHUB_ACTIONS" ] && rm -rf ${KERNEL_SOURCES_DIR}
		mksquashfs ${KBUILD_DIR} output/${KBUILD_DIR}.sfs $COMP
		md5sum output/${KBUILD_DIR}.sfs > output/${KBUILD_DIR}.sfs.md5.txt
		sha256sum output/${KBUILD_DIR}.sfs > output/${KBUILD_DIR}.sfs.sha256.txt
	elif [ -n "$GITHUB_ACTIONS" ]; then
		rm -rf ${KERNEL_SOURCES_DIR}
	fi
fi

#==============================================================


if [ "$kit_kernel" = "yes" ]; then
	KERNEL_MODULES_SFS_NAME="kernel-modules-${package_version}${custom_suffix}-${package_name_suffix}.sfs"
else
	KERNEL_MODULES_SFS_NAME="kernel-modules-${package_version}-${package_name_suffix}.sfs"
fi

if [ "$STRIP_KMODULES" = "yes" ] ; then
 [ -z "$STRIP" ] && STRIP=strip
 if [ "$(which $STRIP)" != "" -a "$($STRIP --help | grep "\--strip-unneeded")" != "" ]; then
	for mods1 in $(find "$(pwd)/output/${linux_kernel_dir}" -type f -name "*.ko")
	do
		file "$mods1" | grep -q "unstripped" || $STRIP --strip-unneeded "$mods1"
	done
 fi
fi
# copy in build.conf
if [ "$kit_kernel" = "yes" ]; then
	cp build.conf output/${linux_kernel_dir}/etc/modules/build.conf-${kernel_version}${custom_suffix}-${today}
else
	cp build.conf output/${linux_kernel_dir}/etc/modules/build.conf-${kernel_version}-${today}
fi

mksquashfs output/${linux_kernel_dir} output/${KERNEL_MODULES_SFS_NAME} $COMP
[ $? = 0 ] || exit 1
[ -n "$GITHUB_ACTIONS" ] && rm -rf output/${linux_kernel_dir}

cd output/
if [ "$kit_kernel" = "yes" ]; then
	log_msg "Kit_Kernel compatible kernel package is ready to package./"
	log_msg "Packaging kit-kernel-${OUTPUT_VERSION} kernel"
	tar -cJvf kit-kernel-${OUTPUT_VERSION}.tar.xz \
	vmlinuz-${OUTPUT_VERSION} ${BOOT_DIR} \
	${KERNEL_MODULES_SFS_NAME} || exit 1
	echo "kit-kernel-${OUTPUT_VERSION}.tar.xz is in output"
	md5sum kit-kernel-${OUTPUT_VERSION}.tar.xz > kit-kernel-${OUTPUT_VERSION}.tar.xz.md5.txt
	sha256sum kit-kernel-${OUTPUT_VERSION}.tar.xz > kit-kernel-${OUTPUT_VERSION}.tar.xz.sha256.txt
else
	log_msg "Huge compatible kernel packages are ready to package."
	log_msg "Packaging huge-${OUTPUT_VERSION} kernel"
	tar -cjvf huge-${OUTPUT_VERSION}.tar.bz2 \
	vmlinuz-${OUTPUT_VERSION} \
	${KERNEL_MODULES_SFS_NAME} || exit 1	
	[ -n "$GITHUB_ACTIONS" ] && rm -f vmlinuz-${OUTPUT_VERSION} ${KERNEL_MODULES_SFS_NAME}
	echo "huge-${OUTPUT_VERSION}.tar.bz2 is in output"
	md5sum huge-${OUTPUT_VERSION}.tar.bz2 > huge-${OUTPUT_VERSION}.tar.bz2.md5.txt
	sha256sum huge-${OUTPUT_VERSION}.tar.bz2 > huge-${OUTPUT_VERSION}.tar.bz2.sha256.txt
fi
echo
cd -

log_msg "Compressing the log"
bzip2 -9 build.log
cp build.log.bz2 output

if [ "$kit_kernel" = "yes" ]; then
log_msg "------------------
Output files:
- kit-kernel-${OUTPUT_VERSION}.tar.xz
  (kernel tarball: vmlinuz, kernel modules sfs - used in the woof process)

- output/${KERNEL_SOURCES_DIR}.sfs
  (you can use this to compile new kernel modules - load or install first..)
------------------"
else
log_msg "------------------
Output files:
- output/huge-${OUTPUT_VERSION}.tar.bz2
  (kernel tarball: vmlinuz, modules.sfs - used in the woof process)
  you can use this to replace vmlinuz and zdrv.sfs from the current wce puppy install..

- output/${KERNEL_SOURCES_DIR}.sfs
  (you can use this to compile new kernel modules - load or install first..)
------------------"
fi

echo "Done!"
[ -n "$GITHUB_ACTIONS" -o ! -f /usr/share/sounds/2barks.au ] || aplay /usr/share/sounds/2barks.au

### END ###
