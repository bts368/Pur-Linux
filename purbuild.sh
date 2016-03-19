#!/bin/bash
set -e
## For moar debugging, before you run the script, run
## 	export PS4='Line ${LINENO}: '
##  (or add to your ~/.bashrc)
## That prints the line number of the current command
## (and with set -x, the actual command) for the script
## being run.-bts,Tue Jan 19 07:29:38 EST 2016
if [ "${PS4}" == 'Line ${LINENO}: ' ];
then
	set -x
fi

# RELEASE VERSION #
PUR_RLS="2016.04"
RLS_MOD="-RELEASE"
RLS_URL="http://g.rainwreck.com/pur"

purlogo() {
cat <<"EOT"
            _   _
__________ (_) (_)       .____    .__                     
\______   \__ _________  |    |   |__| ____  __ _____  ___
 |     ___/  |  \_  __ \ |    |   |  |/    \|  |  \  \/  /
 |    |   |  |  /|  | \/ |    |___|  |   |  \  |  />    < 
 |____|   |____/ |__|    |_______ \__|___|  /____//__/\_ \
                                 \/       \/            \/  

Pür Linux Buildscript Version 1
Pür Linux Version ${PUR_RLS}${RLS_MOD}

You should have received a License file, if you cloned from Github.
If not, please see https://github.com/PurLinux/Base/blob/CURRENT/LICENSE
This script is released under a Simplified 2-Clause BSD license. Support 
truly Free software, and use a BSD license for your projects. 
GPL restrictions just make it Open, not Free.

LFS was originally used for reference, and to bootstrap the project.
FreeBSD inspired this project.
PkgSrc from NetBSD is used as the primary package management utility.
Instead of donating to Pür, go donate to LFS, the FreeBSD project, or NetBSD.
We're a small project, and currently have enough resources to do the needful.
Your money is better spent with the aforementioned projects.

This is the first half of the Pür Linux build process, which occurrs within 
the host environment. At the end, another script is called and run within a chroot.

EOT
}

purlogo

#Deps list:
# GCC
# G++
# GNU Make
# libgmp-dev, libmpfr-dev and libmpc-dev
# gawk
# sed
# grep/egrep
# GNU 'bison' 2.7 or later
# patch
# libencode-perl
# wget or curl

#Uncomment the following Line for Debian 8
# apt-get install gcc g++ make libgmp-dev libmpfr-dev libmpc-dev gawk bison patch sudo texinfo file flex xz-utils

#Important: Key Verification of packages is being implemented in an automated method,
# where this script will fail and print to your screen if a key fails. It requires GPG to be installed
# and may not be implemented for every package yet.

# Build tests are commented out in some places due to some machines just plain being too fast/new.

# Check to make sure sh is a link to bash
if [ "$(sha256sum $(which sh) | awk '{print $1}')" != "$(sha256sum $(which bash) | awk '{print $1}')" ];
then
	echo " /!\ /!\ /!\ WARNING WARNING WARNING /!\ /!\ /!\ /!\ "
        echo " Your $(which sh) is NOT linked to $(which bash)!!   "
	echo " Please fix this (i.e. via: ln -sf $(which bash) $(which sh)"
        echo "/!\ /!\ /!\ WARNING WARNING WARNING /!\ /!\ /!\ /!\ "
        exit 1
fi

if [[ "$(whoami)" == "root" ]]; then
        echo " /!\ /!\ /!\ WARNING WARNING WARNING /!\ /!\ /!\ /!\ "
        echo " Don't run me as root. Create a new user!!      "
        echo "/!\ /!\ /!\ WARNING WARNING WARNING /!\ /!\ /!\ /!\ "
        exit 1
fi

echo

# Are we using curl or wget?
if ! type curl > /dev/null 2>&1; then
        fetch_cmd="$(which wget) -c --progress=bar --tries=5 --waitretry 3 -a /tmp/fetch.log"
else
        fetch_cmd="$(which curl) --progress-bar -LSOf --retry 5 --retry-delay 3 -C -"
fi


# Setting up ENV
echo "Setting up the environment and cleaning results from previous runs if necessary..."
env -i HOME=${HOME} TERM=${TERM} PS1='\u:\w\$ ' > /dev/null 2>&1
set +h
umask 022

echo

# Scrub/create paths
#rm -rf ${HOME}/purroot
mkdir -p ${HOME}/purroot
PUR=${HOME}/purroot
PLOGS=${PUR}/logs
rm -rf ${PLOGS}
mkdir -p ${PLOGS}

# clean up from previous failed runs
if [ -z "${PUR}" ];
then
	echo "PUR VARIABLE IS UNSET! Further process will cause host system damage."
	exit 1
fi
set +e
sudo umount -l ${PUR}/{run,sys,proc,dev} > /dev/null 2>&1
sudo rm -rf ${PUR}/{bin,boot,etc,home,lib,mnt,opt,run,sys,proc,dev} > /dev/null 2>&1
set -e
# sudo is needed if tools has been chown'd
PTLS=/tools
PSRC=${PUR}/sources
PCNTRB=${PUR}/contrib
sudo rm -rf ${PTLS}
mkdir -p ${PUR}/tools
mkdir -p ${PSRC}
find ${PSRC}/. -maxdepth 1 -ignore_readdir_race -type d -exec rm -rf '{}' \; > /dev/null 2>&1
sudo chmod a+wt ${PSRC}
mkdir -p ${PCNTRB}
find ${PCNTRB}/. -maxdepth 1 -ignore_readdir_race -type d -exec rm -rf '{}' \; > /dev/null 2>&1
LC_ALL=POSIX
PUR_TGT="$(uname -m)-pur-linux-gnu"
sudo rm -rf ${PTLS}
sudo ln -s ${PUR}/tools /

rm -rf ${PTLS}/include
mkdir -p ${PTLS}/include
PATH=${PTLS}/bin:/usr/local/bin:/bin:/usr/bin
export LC_ALL PUR_TGT PATH PBLD

rm -rf ${HOME}/specs
mkdir -p ${HOME}/specs
sudo ln -s ${HOME}/specs /specs
if [ "${USER}" == 'bts' ];
then
	export MAKEFLAGS="-j $(($(egrep '^processor[[:space:]]*:' /proc/cpuinfo | wc -l)+1))"
fi
ulimit -n 512 ## Needed for building GNU Make on Debian


#Fetching everything.
cd ${PSRC}
echo "Fetching source tarballs (if necessary) and cleaning up from previous builds (if necessary). This may take a while..."
# using the official LFS mirror- ftp://mirrors-usa.go-parts.com/lfs/lfs-packages/7.8/- because upstream sites/mirrors are stupid and do things like not support RETRY.
# luckily, they bundle the entire archive in one handy tarball.
find . -maxdepth 1 -ignore_readdir_race -type d -exec rm -rf '{}' \; > /dev/null 2>&1
find . -maxdepth 1 -ignore_readdir_race -type f -not -name "pur_src*.tar.xz" -delete > /dev/null 2>&1
if [ -f "pur_src.${PUR_RLS}${RLS_MOD}.tar.xz" ];
then
	if type sha256sum > /dev/null 2>&1;
	then
		echo "Checking integrity..."
		${fetch_cmd} -s "${RLS_URL}/pur_src.${PUR_RLS}${RLS_MOD}.tar.xz.sha256"
		set +e
		$(which sha256sum) -c pur_src.${PUR_RLS}${RLS_MOD}.tar.xz.sha256
		if [ "${?}" != '0' ];
		then
			echo "SHA256 checksum failed. Try deleting ${PSRC}/pur_src.${PUR_RLS}${RLS_MOD}.tar.xz and re-running."
			exit 1
		fi
		set -e
	fi
else
	${fetch_cmd} ${RLS_URL}/pur_src.${PUR_RLS}${RLS_MOD}.tar.xz
	if type sha256sum > /dev/null 2>&1;
	then
		echo "Checking integrity..."
		${fetch_cmd} -s "${RLS_URL}/pur_src.${PUR_RLS}${RLS_MOD}.tar.xz.sha256"
		set +e
		$(which sha256sum) -c pur_src.${PUR_RLS}${RLS_MOD}.tar.xz.sha256
		if [ "${?}" != '0' ];
		then
			echo "SHA256 checksum failed. Try deleting ${PSRC}/pur_src.${PUR_RLS}${RLS_MOD}.tar.xz and re-running."
			exit 1
		fi
		set -e
	fi
fi
echo "Extracting main packageset..."
tar --totals -Jxf pur_src.${PUR_RLS}${RLS_MOD}.tar.xz
cd pur_src/core
mv * ${PSRC}
cd ../contrib
mv * ${PCNTRB}
rm -rf pur_src
cd ${PSRC}
GLIBCVERS=$(egrep '^glibc-[0-9]' versions.txt | sed -re 's/[A-Za-z]-(.*)$/\1/g')
HOSTGLIBCVERS="2.11"
GCCVER=$(egrep '^gcc-[0-9]' versions.txt | sed -re 's/[A-Za-z]*-(.*)$/\1/g')
PERLVER=$(egrep '^perl-[0-9]' versions.txt | sed -re 's/[A-Za-z]*-(.*)$/\1/g')
PERLMAJ=$(echo ${PERLVER} | sed -re 's/([0-9]*)\..*$/\1/g')
TCLVER=$(egrep '^tcl-[0-9]' versions.txt | sed -re 's/[A-Za-z]*-(.*)$/\1/g' | awk -F. '{print $1"."$2}')
export GLIBCVERS HOSTGLIBCVERS GCCVER PERLVER PERLMAJ TLCVER

echo



############################################
# BUILDING BOOTSTRAP ENVIRONMENT IN /TOOLS #
############################################

#binutils first build
echo "Binutils - first pass."
mkdir ${PTLS}/lib
case $(uname -m) in
  x86_64) ln -s /tools/lib /tools/lib64 ;;
esac
cd ${PSRC}
rm -rf binutils-build
cp -a binutils binutils-build
cd binutils-build
echo "[Binutils] Configuring..."
./configure --prefix=/tools     \
    --with-sysroot=${PUR}       \
    --with-lib-path=${PTLS}/lib  \
    --target=${PUR_TGT}         \
    --disable-nls               \
    --disable-werror > ${PLOGS}/binutils_configure.1 2>&1

echo "[Binutils] Building..."
make > ${PLOGS}/binutils_make.1 2>&1
make install >> ${PLOGS}/binutils_make.1 2>&1
cd ${PSRC}
rm -rf binutils-build

## building GCC first run.
echo "GCC - first pass."
#GCC DEPS
# May want to consider this in the future, just for keeping compat with GCC's suggested practices:
# Using  ./contrib/download_prerequisites instead of manually grabbing

# building MPFR
echo "[GCC] MPFR"
cd gcc
rm -rf gcc-build
mkdir gcc-build
cd gcc-build
cp -a ../mpfr .

# MPC
echo "[GCC] MPC"
cp -a ../mpc .

#GMP
echo "[GCC] GMP"
cp -a ../gmp .

#GCC TIME BABY OH YEAH
echo "[GCC] Configuring..."
for file in $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h);
do
  #cp -u ${file}{,.orig}
  sed -i -re 's@/lib(64)?(32)?/ld@/tools&@g' -e 's@/usr@/tools@g' ${file}
  echo "
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 \"${PTLS}/lib/\"
#define STANDARD_STARTFILE_PREFIX_2 \"\"" >> ${file}
  #touch ${file}.orig
done
../configure					\
    --target=${PUR_TGT}					\
    --prefix=${PTLS}					\
    --with-glibc-version=${HOSTGLIBCVERS}		\
    --with-sysroot=${PUR}				\
    --with-newlib					\
    --without-headers					\
    --with-local-prefix=${PTLS}				\
    --with-native-system-header-dir=${PTLS}/include	\
    --disable-nls					\
    --disable-shared					\
    --disable-multilib					\
    --disable-decimal-float				\
    --disable-threads					\
    --disable-libatomic					\
    --disable-libgomp					\
    --disable-libquadmath				\
    --disable-libssp					\
    --disable-libvtv					\
    --disable-libstdcxx					\
    --enable-languages=c,c++ > ${PLOGS}/gcc_configure.1 2>&1

echo "[GCC] Building..."
make > ${PLOGS}/gcc_make.1 2>&1
make install >> ${PLOGS}/gcc_make.1 2>&1
cd ${PSRC}
rm -rf gcc/gcc-build

## Grabbing latest kernel headers
echo "[Kernel] Making and installing headers..."
rm -rf linux-build
cp -a linux linux-build
cd linux-build
make mrproper > ${PLOGS}/kernel-headers_make.1 2>&1
make INSTALL_HDR_PATH=dest headers_install >> ${PLOGS}/kernel-headers_make.1 2>&1
cp -r dest/include/* ${PTLS}/include
cd ${PSRC}
rm -rf linux-build

# Building glibc - first pass
echo "GlibC - first pass."
cd glibc
rm -rf glibc-build
mkdir glibc-build
cd glibc-build
echo "[GlibC] Configuring..."
../configure						\
      --prefix=${PTLS}					\
      --host=${PUR_TGT}					\
      --build=$(../scripts/config.guess)		\
      --disable-profile					\
      --enable-kernel=2.6.32				\
      --enable-obsolete-rpc				\
      --with-headers=${PTLS}/include			\
      libc_cv_forced_unwind=yes				\
      libc_cv_ctors_header=yes				\
      libc_cv_c_cleanup=yes > ${PLOGS}/glibc_configure.1 2>&1
# Note: the below was originally enabled.
# However, this version of GlibC is scrapped in the final version and likely the umlaut
# might break things- so disabling for sane initial toolchain.
#      --with-pkgversion='Pür Linux glibc'                 \

echo "[GlibC] Building..."
make > ${PLOGS}/glibc_make.1 2>&1
make install >> ${PLOGS}/glibc_make.1 2>&1

# Testing!
echo -n "Runnning tests before continuing... "
echo 'int main(){}' > dummy.c
${PUR_TGT}-gcc dummy.c
if readelf -l a.out | grep ': /tools' | grep -q ld-linux-x86-64.so.2;
then
	echo "Test passed."
	rm dummy.c a.out
else
	echo "Test Failed. Now Exiting, post glibc build."
	rm dummy.c a.out
	exit 1
fi
cd ${PSRC}
rm -rf glibc/glibc-build

#libstc++
echo "LibstdC++ - first pass."
cd gcc
rm -rf gcc-build
mkdir gcc-build
cd gcc-build
echo "[LibstdC++] Configuring..."
../libstdc++-v3/configure		\
    --host=${PUR_TGT}			\
    --prefix=${PTLS}			\
    --disable-multilib			\
    --disable-nls			\
    --disable-libstdcxx-threads		\
    --disable-libstdcxx-pch		\
    --with-gxx-include-dir=${PTLS}/${PUR_TGT}/include/c++/${GCCVER} > ${PLOGS}/libstdc++_configure.1 2>&1

echo "[LibstdC++] Building..."
make > ${PLOGS}/libstdc++_make.1 2>&1
make install >> ${PLOGS}/libstdc++_make.1 2>&1
cd ${PSRC}
rm -rf gcc-build


##############################
# BUILDING TOOLKIT IN /TOOLS #
##############################

# binutils pass 2
echo "Binutils - second pass."
rm -rf binutils-build
cp -a binutils binutils-build
cd binutils-build
echo "[Binutils] Configuring..."
CC=${PUR_TGT}-gcc		\
AR=${PUR_TGT}-ar		\
RANLIB=${PUR_TGT}-ranlib	\
./configure			\
    --prefix=${PTLS}		\
    --disable-nls		\
    --disable-werror		\
    --with-lib-path=${PTLS}/lib	\
    --with-sysroot > ${PLOGS}/binutils_configure.2 2>&1

echo "[Binutils] Building..."
make > ${PLOGS}/binutils_make.2 2>&1
make install >> ${PLOGS}/binutils_make.2 2>&1
#fiddly bits
make -C ld clean > ${PLOGS}/binutils_post-tweaks.2 2>&1
make -C ld LIB_PATH=/usr/lib:/lib >> ${PLOGS}/binutils_post-tweaks.2 2>&1
cp ld/ld-new ${PTLS}/bin
cd ${PSRC}
rm -rf binutils-build

# GCC round 2
echo "GCC - second pass."
rm -rf gcc-build gcc-build2
mkdir gcc-build2
cp -a gcc gcc-build
cd ${PTLS}/lib
cat gcc/${PUR_TGT}/${GCCVER}/plugin/include/limitx.h	\
 gcc/${PUR_TGT}/${GCCVER}/plugin/include/glimits.h	\
 gcc/${PUR_TGT}/${GCCVER}/plugin/include/limity.h > $(dirname $(${PUR_TGT}-gcc -print-libgcc-file-name))/include-fixed/limits.h
for file in $(find gcc/${PUR_TGT}/${GCCVER}/plugin/include/config -name linux64.h -o -name linux.h -o -name sysv4.h);
do
  cp -u ${file}{,.orig}
  sed -re 's@/lib(64)?(32)?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' ${file}.orig > ${file}
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> ${file}
  touch ${file}.orig
done
cd ${PSRC}/gcc-build2

echo "[GCC] MPFR"
cp -a ../mpfr .

echo "[GCC] MPC"
cp -a ../mpc .

echo "[GCC] GMP"
cp -a ../gmp .

find ./ -name 'config.cache' -exec rm -rf '{}' \;
echo "[GCC] Configuring..."
CC=${PUR_TGT}-gcc					\
CXX=${PUR_TGT}-g++					\
AR=${PUR_TGT}-ar					\
RANLIB=${PUR_TGT}-ranlib				\
../gcc-build/configure						\
    --prefix=${PTLS}					\
    --with-local-prefix=${PTLS}				\
    --with-native-system-header-dir=${PTLS}/include	\
    --enable-languages=c,c++				\
    --disable-libstdcxx-pch				\
    --disable-multilib					\
    --disable-bootstrap					\
    --disable-libgomp > ${PLOGS}/gcc_configure.2 2>&1

echo "[GCC] Building..."
make > ${PLOGS}/gcc_make.2 2>&1
make install >> ${PLOGS}/gcc_make.2 2>&1
ln -s gcc /tools/bin/cc

#testing again
echo -n "Runnning tests before continuing... "
echo 'int main(){}' > dummy.c
${PUR_TGT}-gcc dummy.c
if readelf -l a.out | grep ': /tools' | grep -q ld-linux;
then
	echo "Test passed."
	rm dummy.c a.out
else
	echo "Test Failed. Now Exiting, post GCC Round 2 build"
        rm dummy.c a.out
        exit 1
fi
cd ${PSRC}
rm -rf gcc-build gcc-build2

## Tests
echo "Running further tests..."
# TCL
rm -rf tcl-build
cp -a tcl tcl-build
cd tcl-build/unix
echo "[TCL] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/tcl_configure.1 2>&1
echo "[TCL] Building..."
make > ${PLOGS}/tcl_make.1 2>&1
TZ=UTC make test >> ${PLOGS}/tcl_test.1 2>&1
make install >> ${PLOGS}/tcl_test.1 2>&1
chmod u+w ${PTLS}/lib/libtcl${TCLVER}.so
make install-private-headers >> ${PLOGS}/tcl_test.1 2>&1
ln -s tclsh${TCLVER} /tools/bin/tclsh
cd ${PSRC}
rm -rf tcl-build

#Expect
rm -rf expect-build
cp -a expect expect-build
cd expect-build
echo "[Expect] Configuring..."
sed -i -e 's:/usr/local/bin:/bin:' configure
./configure --prefix=${PTLS}		\
            --with-tcl=${PTLS}/lib	\
            --with-tclinclude=${PTLS}/include > ${PLOGS}/expect_configure.1 2>&1

echo "[Expect] Building..."
make > ${PLOGS}/expect_make.1 2>&1
make tests >> ${PLOGS}/expect_make.1 2>&1
make SCRIPTS="" install >> ${PLOGS}/expect_make.1 2>&1
cd ${PSRC}
rm -rf expect-build

#DejaGNU
rm -rf dejagnu-build
cp -a dejagnu deagnu-build
cd dejagnu-build
echo "[DejaGNU] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/dejagnu_configure.1 2>&1

echo "[DejaGNU] Building..."
make install > ${PLOGS}/dejagnu_make.1 2>&1
#make check >> ${PLOGS}/dejagnu_make.1 2>&1
cd ${PSRC}
rm -rf dejagnu-build

#check
rm -rf check-build
cp -a check check-build
cd check-build
echo "[Check] Configuring..."
# this is necessary since we download from git rather than sourceforge. fuck sourceforge.
autoreconf --install
PKG_CONFIG= ./configure --prefix=${PTLS} > ${PLOGS}/check_configure.1 2>&1

echo "[Check] Building..."
make > ${PLOGS}/check_make.1 2>&1
#make check >> ${PLOGS}/check_make.1 2>&1
make install >> ${PLOGS}/check_make.1 2>&1
cd ${PSRC}
rm -rf check-build

#ncurses
rm -rf ncurses-build
cp -a ncurses ncurses-build
cd ncurses-build
echo "[nCurses] Configuring..."
sed -i -e 's/mawk//' configure
./configure --prefix=${PTLS}	\
            --with-shared	\
            --without-debug	\
            --without-ada	\
            --enable-widec	\
            --enable-overwrite > ${PLOGS}/ncurses_configure.1 2>&1

echo "[nCurses] Building..."
make > ${PLOGS}/ncurses_make.1 2>&1
make install >> ${PLOGS}/ncurses_make.1 2>&1
cd ${PSRC}
rm -rf ncurses-build

#bash
rm -rf bash-build
cp -a bash bash-build
cd bash-build
echo "[Bash] Configuring..."
./configure --prefix=${PTLS} --without-bash-malloc > ${PLOGS}/bash_configure.1 2>&1

echo "[Bash] Building..."
make > ${PLOGS}/bash_make.1 2>&1
# make tests >> ${PLOGS}/bash_make.1 2>&1
make install >> ${PLOGS}/bash_make.1 2>&1
ln -s bash ${PTLS}/bin/sh
cd ${PSRC}
rm -rf bash-build

#Bzip2
rm -rf bzip2-build
cp -a bzip2 bzip2-build
cd bzip2-build
echo "[Bzip2] Building..."
make > ${PLOGS}/bzip2_make.1 2>&1
make PREFIX=${PTLS} install >> ${PLOGS}/bzip2_make.1 2>&1
cd ${PSRC}
rm -rf bzip2-build

#Coreutils
rm -rf coreutils-build
cp -a coreutils coreutils-build
cd coreutils-build
echo "[Coreutils] Configuring..."
./configure --prefix=${PTLS} --enable-install-program=hostname > ${PLOGS}/coreutils_configure.1 2>&1

echo "[Coreutils] Building..."
make > ${PLOGS}/coreutils_make.1 2>&1
# make RUN_EXPENSIVE_TESTS=yes check >> ${PLOGS}/coreutils_make.1 2>&1
make install >> ${PLOGS}/coreutils_make.1 2>&1
cd ${PSRC}
rm -rf coreutils-build

#Diffutils
rm -rf diffutils-build
cp -a diffutils diffutils-build
cd diffutils-build
echo "[Diffutils] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/diffutils_configure.1 2>&1

echo "[Diffutils] Building..."
make > ${PLOGS}/diffutils_make.1 2>&1
# make check >> ${PLOGS}/diffutils_make.1 2>&1
make install >> ${PLOGS}/diffutils_make.1 2>&1
cd ${PSRC}
rm -rf diffutils-build

# File
rm -rf file-build
cp -a file file-build
cd file-build
echo "[File] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/file_configure.1 2>&1

echo "[File] Building..."
make > ${PLOGS}/file_make.1 2>&1
#make check >> ${PLOGS}/file_make.1 2>&1
make install >> ${PLOGS}/file_make.1 2>&1
cd ${PSRC}
rm -rf file-build

# Findutils
rm -rf findutils-build
cp -a findutils findutils-build
cd findutils-build
echo "[Findutils] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/findutils_configure.1 2>&1

echo "[Findutils] Building..."
make > ${PLOGS}/findutils_make.1 2>&1
#make check >> ${PLOGS}/findutils_makee.1 2>&1
make install >> ${PLOGS}/findutils_makee.1 2>&1
cd ${PSRC}
rm -rf findutils-build

# GAWK
rm -rf gawk-build
cp -a gawk gawk-build
cd gawk-build
echo "[Gawk] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/gawk_configure.1 2>&1

echo "[Gawk] Building..."
make > ${PLOGS}/gawk_make.1 2>&1
#make check >> ${PLOGS}/gawk_make.1 2>&1
make install >> ${PLOGS}/gawk_make.1 2>&1
cd ${PSRC}
rm -rf gawk-build

#gettext
rm -rf gettext-build
cp -a gettext gettext-build
cd gettext-build/gettext-tools
echo "[Gettext] Configuring..."
EMACS="no" ./configure --prefix=${PTLS} --disable-shared > ${PLOGS}/gettext_configure.1 2>&1

echo "[Gettext] Building..."
make -C gnulib-lib > ${PLOGS}/gettext_make.1 2>&1
make -C intl pluralx.c >> ${PLOGS}/gettext_make.1 2>&1
make -C src msgfmt >> ${PLOGS}/gettext_make.1 2>&1
make -C src msgmerge >> ${PLOGS}/gettext_make.1 2>&1
make -C src xgettext >> ${PLOGS}/gettext_make.1 2>&1
cp src/{msgfmt,msgmerge,xgettext} ${PTLS}/bin
cd ${PSRC}
rm -rf gettext-build

# GNU Grep
rm -rf grep-build
cp -a grep grep-build
cd grep-build
echo "[Grep] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/grep_configure.1 2>&1

echo "[Grep] Building..."
make > ${PLOGS}/grep_make.1 2>&1
#make check >> ${PLOGS}/grep_make.1 2>&1
make install >> ${PLOGS}/grep_make.1 2>&1
cd ${PSRC}
rm -rf grep-build

# GNU GZip
rm -rf gzip-build
cp -a gzip gzip-build
cd gzip-build
echo "[Gzip] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/gzip_configure.1 2>&1

echo "[Gzip] Building..."
make > ${PLOGS}/gzip_make.1 2>&1
#make check >> ${PLOGS}/gzip_make.1 2>&1
make install >> ${PLOGS}/gzip_make.1 2>&1
cd ${PSRC}
rm -rf gzip-build

# M4
rm -rf m4-build
cp -a m4 m4-build
cd m4-build
echo "[M4] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/m4_configure.1 2>&1

echo "[M4] Building..."
make > ${PLOGS}/m4_make.1 2>&1
#make check >> ${PLOGS}/m4_make.1 2>&1
make install >> ${PLOGS}/m4_make.1 2>&1
cd ${PSRC}
rm -rf m4-build

# GNU Make
rm -rf make-build
cp -a make make-build
cd make-build
echo "[Make] Configuring..."
./configure --prefix=${PTLS} --without-guile > ${PLOGS}/make_configure.1 2>&1

echo "[Make] Building..."
make > ${PLOGS}/make_make.1 2>&1
#make check >> ${PLOGS}/make_make.1 2>&1
make install >> ${PLOGS}/make_make.1 2>&1
cd ${PSRC}
rm -rf make-build

#GNU Patch
rm -rf patch-build
cp -a patch patch-build
cd patch-build
echo "[Patch] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/patch_configure.1 2>&1

echo "[Patch] Building..."
make > ${PLOGS}/patch_make.1 2>&1
#make check >> ${PLOGS}/patch_make.1 2>&1
make install >> ${PLOGS}/patch_make.1 2>&1
cd ${PSRC}
rm -rf patch-build

# Perl (Will be removed from Base eventually/hopefully)
rm -rf perl-build
cp -a perl perl-build
cd perl-build
echo "[Perl] Configuring..."
sh Configure -des -Dprefix=${PTLS} -Dlibs=-lm > ${PLOGS}/perl_configure.1 2>&1

echo "[Perl] Building..."
make > ${PLOGS}/perl_make.1 2>&1
cp perl cpan/podlators/pod2man ${PTLS}/bin
mkdir -p ${PTLS}/lib/perl${PERLMAJ}/${PERLVER}
cp -R lib/* ${PTLS}/lib/perl${PERLMAJ}/${PERLVER}
cd ${PSRC}
rm -rf perl-build

#GNU Sed
rm -rf sed-build
cp -a sed sed-build
cd sed-build
echo "[Sed] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/sed_configure.1 2>&1

echo "[Sed] Building..."
make > ${PLOGS}/sed_make.1 2>&1
#make check >> ${PLOGS}/sed_make.1 2>&1
make install >> ${PLOGS}/sed_make.1 2>&1
cd ${PSRC}
rm -rf sed-build

#GNU Tar
rm -rf tar-build
cp -a tar tar-build
cd tar-build
echo "[Tar] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/tar_configure.1 2>&1

echo "[Tar] Building..."
make > ${PLOGS}/tar_make.1 2>&1
#make check >> ${PLOGS}/tar_make.1 2>&1
make install >> ${PLOGS}/tar_make.1 2>&1
cd ${PSRC}
rm -rf tar-build

#GNU Texinfo
rm -rf texinfo-build
cp -a texinfo texinfo-build
cd texinfo-build
echo "[Texinfo] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/texinfo_configure.1 2>&1

echo "[Texinfo] Building..."
make > ${PLOGS}/texinfo_make.1 2>&1
#make check >> ${PLOGS}/texinfo_make.1 2>&1
make install >> ${PLOGS}/texinfo_make.1 2>&1
cd ${PSRC}
rm -rf texinfo-build

# Util-Linux
rm -rf util-linux-build
cp -a util-linux util-linux-build
cd util-linux-build
echo "[Util-Linux] Configuring..."
./configure --prefix=${PTLS}			\
            --without-python			\
            --disable-makeinstall-chown		\
            --without-systemdsystemunitdir	\
            PKG_CONFIG="" > ${PLOGS}/util-linux_configure.1 2>&1

echo "[Util-Linux] Building..."
make > ${PLOGS}/util-linux_make.1 2>&1
make install >> ${PLOGS}/util-linux_make.1 2>&1
cd ${PSRC}
rm -rf util-linux-build

#Xz
rm -rf xz-build
cp -a xz xz-build
cd xz-build
echo "[Xz] Configuring..."
./configure --prefix=${PTLS} > ${PLOGS}/xz_configure.1 2>&1

echo "[Xz] Building..."
make > ${PLOGS}/xz_make.1 2>&1
#make check >> ${PLOGS}/xz_make.1 2>&1
make install >> ${PLOGS}/xz_make.1 2>&1
cd ${PSRC}
rm -rf xz-build

# Stripping bootstrap env
# strip throws a non-0 because some /usr/bin's are actually bash scripts, etc.
set +e
strip --strip-debug ${PTLS}/lib/*
/usr/bin/strip --strip-unneeded ${PTLS}/{,s}bin/*
set -e
rm -rf ${PTLS}/{,share}/{info,man,doc}

# CHOWNing Bootstrap
sudo chown -R root:root ${PUR}/tools


############################################
# PREPPING CHROOT                          #
############################################

#Device Nodes
sudo mkdir -p ${PUR}/{dev,proc,sys,run}
sudo mknod -m 600 ${PUR}/dev/console c 5 1
sudo mknod -m 666 ${PUR}/dev/null c 1 3
# Temporary workaround? Either going with eudev or the old static way, not sure yet! Wheee putting off decisions!
# I vote for eudev, personally. It'll give us way better hardware detection/hotplugging/etc. support. -bts. Thu Jan 21 09:14:51 EST 2016
sudo mount --bind /dev ${PUR}/dev
sudo mount -t devpts devpts ${PUR}/dev/pts -o gid=5,mode=620
sudo mount -t proc proc ${PUR}/proc
sudo mount -t sysfs sysfs ${PUR}/sys
sudo mount -t tmpfs tmpfs ${PUR}/run
if [ -h ${PUR}/dev/shm ];
then
	sudo mkdir -p ${PUR}/$(readlink ${PUR}/dev/shm)
fi
# Entering chroot 
cd ${PUR}
rm -f chrootboot{,-stage2}.sh
if [ "${USER}" == 'bts' ];
then
	# used in development
	${fetch_cmd} http://10.1.1.1/pur/chrootboot.sh
	${fetch_cmd} http://10.1.1.1/pur/chrootboot-stage2.sh
else
	${fetch_cmd} https://raw.githubusercontent.com/PurLinux/Base/CURRENT/chrootboot.sh
	${fetch_cmd} https://raw.githubusercontent.com/PurLinux/Base/CURRENT/chrootboot-stage2.sh
fi
chmod +x chrootboot.sh
chmod +x chrootboot-stage2.sh
echo "ENTERING CHROOT"
sudo chroot "${PUR}" /tools/bin/env -i      			\
		HOME=/root					\
		TERM="${TERM}"					\
		PS1='\u:\w (chroot) \$ '			\
		PS4="${PS4}"					\
		PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin	\
		GCCVER=${GCCVER}				\
		VIMVER=${VIMVER}				\
		/tools/bin/bash +h /chrootboot.sh

touch ${PUR}/chrootboot1.success

sudo chroot "${PUR}" /tools/bin/env -i HOME=/root TERM=$TERM	\
		PS1='\u:\w\$ '					\
		PATH=/bin:/usr/bin:/sbin:/usr/sbin		\
		/tools/bin/find /{,usr/}{bin,lib,sbin} -type f	\
		-exec /tools/bin/strip --strip-debug '{}' ';'

touch ${PUR}/chrootboot2.success

sudo chroot "${PUR}" /tools/bin/env -i      			\
		HOME=/root					\
		TERM="${TERM}"					\
		PS1='\u:\w (chroot) \$ '			\
		PS4="${PS4}"					\
		PATH=/bin:/usr/bin:/sbin:/usr/sbin		\
		GCCVER=${GCCVER}				\
		VIMVER=${VIMVER}				\
		/tools/bin/bash +h /chrootboot-stage2.sh

touch ${PUR}/chrootboot3.success

sudo umount -l ${PUR}/{run,sys,proc,dev} > /dev/null 2>&1

rm -f ${PSRC}/pur_src.${PUR_RLS}${RLS_MOD}.tar.xz{,.sha256}
