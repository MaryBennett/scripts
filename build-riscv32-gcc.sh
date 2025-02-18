#!/usr/bin/env bash
# Script for building a RISC-V GNU Toolchain from sources

#======================================================================
# Variables
#======================================================================

PARALLEL=12

DEFAULTSRC=${PWD}
DEFAULTARCH=rv32imac
DEFAULTABI=ilp32
SCRIPTDIR=$(dirname "$0")

src_dir=${DEFAULTSRC}
clean_op=0

which gcc
which g++

#======================================================================
# Support functions
#======================================================================

__die()
{
    echo ${*}
    exit 1
}

__banner()
{
    echo "============================================================"
    echo ${*}
    echo "============================================================"
}

__abort()
{
        cat <<EOF
***************
*** ABORTED ***
***************
An error occurred. Exiting...
EOF
        exit 1
}

# Set script to abort on any command that results an error status
trap '__abort' 0
set -e

#======================================================================
# Set user input
#======================================================================

while getopts "s:c" opt; do
  case ${opt} in
    s) src_dir=${OPTARG} ;;
    c) clean_op=1 ;;
    ?) __die "Invalid option ${OPTARG}" ;;
  esac
done

install_dir=${src_dir}/install
build_dir=${src_dir}/build

#======================================================================
# Set up the environment
#======================================================================

#__banner Download Dependancies

#apt-get install -y flex bison build-essential dejagnu git python-is-python3 python3 texinfo wget libexpat-dev rsync file \
#gawk zlib1g-dev ninja-build pkg-config libglib2.0-dev python3-venv cmake

if [ ! -d "${src_dir}" ]; then
  __banner Creating source directory
  mkdir --verbose -p ${src_dir}
fi

__banner Cloning sources

source ${SCRIPTDIR}/clone-riscv32-gcc.sh ${src_dir}

if [ ${clean_op} -eq 1 ]; then
  __banner Cleaning environment
  rm -rf ${build_dir}
  rm -rf ${install_dir}
fi

for d in  "${build_dir}" "${install_dir}" ; do
    test  -d "$d" || mkdir --verbose -p $d
done

#======================================================================
# Binutils-gdb
#======================================================================

__banner Download libgmp and libmpfr

if [ ! -e ${src_dir}/binutils-gdb/gmp ]; then
  if [ ! -e "${src_dir}/gmp-6.2.1.tar.bz2" ]; then
    wget --verbose https://gmplib.org/download/gmp/gmp-6.2.1.tar.bz2 --directory-prefix="${src_dir}"
  fi
  tar -xjf ${src_dir}/gmp-6.2.1.tar.bz2
  mv ${src_dir}/gmp-6.2.1 ${src_dir}/binutils-gdb/gmp
fi

if [ ! -e ${src_dir}/binutils-gdb/mpfr ]; then
  if [ ! -e "${src_dir}/mpfr-4.2.1.tar.bz2" ]; then
    wget --verbose https://www.mpfr.org/mpfr-current/mpfr-4.2.1.tar.bz2 --directory-prefix="${src_dir}"
  fi
  tar -xjf ${src_dir}/mpfr-4.2.1.tar.bz2
  mv ${src_dir}/mpfr-4.2.1 ${src_dir}/binutils-gdb/mpfr
fi

__banner Configure binutils-gdb

mkdir -p ${build_dir}/binutils-gdb
cd ${build_dir}/binutils-gdb
CFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
CXXFLAGS="-g -O2 -Wno-error=implicit-function-declaration" \
${src_dir}/binutils-gdb/configure        \
    --target=riscv32-unknown-elf    \
    --prefix=${install_dir}       \
    --with-expat                    \
    --disable-werror

__banner Building binutils-gdb

make -j${PARALLEL}
make install

#======================================================================
# GCC - Stage 1
#======================================================================

__banner Configure GCC - Stage 1

cd ${src_dir}/gcc
./contrib/download_prerequisites
mkdir -p ${build_dir}/gcc-stage1
cd ${build_dir}/gcc-stage1
${src_dir}/gcc/configure                                   \
    --target=riscv32-unknown-elf                        \
    --prefix=${install_dir}                           \
    --with-sysroot=${install_dir}/riscv32-unknown-elf \
    --with-newlib                                       \
    --disable-libssp					\
    --without-headers                                   \
    --disable-shared                                    \
    --disable-threads \
    --disable-tls \
    --enable-languages=c,c++ \
    --disable-libmudflap \
    --disable-libssp \
    --disable-libquadmath \
    --disable-libgomp \
    --disable-nls \
    --disable-werror

__banner Building GCC - Stage 1

make -j${PARALLEL}
make install

#======================================================================
# Newlib
#======================================================================

__banner Configure newlib

PATH=${install_dir}/bin:$PATH
mkdir -p ${build_dir}/newlib
cd ${build_dir}/newlib
CFLAGS_FOR_TARGET="-O2 -mcmodel=medany -D_POSIX_MODE -ffunction-sections -fdata-sections"            \
CXXFLAGS_FOR_TARGET="-O2 -mcmodel=medany -D_POSIX_MODE -ffunction-sections -fdata-sections"            \
${src_dir}/newlib/configure                      \
    --target=riscv32-unknown-elf                   \
    --prefix=${install_dir}                      \
    --with-arch=${DEFAULTARCH}                     \
    --with-abi=${DEFAULTABI}                       \
    --enable-multilib                              \
    --enable-newlib-io-long-double                 \
    --enable-newlib-io-long-long                   \
    --enable-newlib-io-c99-formats                 \
    --enable-newlib-register-fini

__banner Building newlib

make -j${PARALLEL}
make install

#======================================================================
# Newlib Nano (& merge)
#======================================================================

__banner Configure newlib nano

mkdir -p ${build_dir}/newlib-nano
cd ${build_dir}/newlib-nano
CFLAGS_FOR_TARGET="-Os -mcmodel=medany -ffunction-sections -fdata-sections" \
${src_dir}/newlib/configure                      \
    --target=riscv32-unknown-elf                   \
    --prefix=${build_dir}/newlib-nano-inst       \
    --with-arch=${DEFAULTARCH}                     \
    --with-abi=${DEFAULTABI}                       \
    --enable-multilib                              \
    --enable-newlib-reent-small                    \
    --disable-newlib-fvwrite-in-streamio           \
    --disable-newlib-fseek-optimization            \
    --disable-newlib-wide-orient                   \
    --enable-newlib-nano-malloc                    \
    --disable-newlib-unbuf-stream-opt              \
    --enable-lite-exit                             \
    --enable-newlib-global-atexit                  \
    --enable-newlib-nano-formatted-io              \
    --disable-newlib-supplied-syscalls             \
    --disable-nls

__banner Building newlib nano

make -j${PARALLEL}
make install

__banner Merging newlib and newlib nano

for multilib in $(riscv32-unknown-elf-gcc --print-multi-lib); do
  multilibdir=$(echo ${multilib} | sed 's/;.*//')
  for file in libc.a libm.a libg.a libgloss.a; do
    cp ${build_dir}/newlib-nano-inst/${multilibdir}/${file} ${install_dir}/riscv32-unknown-elf/lib/${multilibdir}/${file}
  done
  cp ${build_dir}/newlib-nano-inst/${multilibdir}/crt0.o ${install_dir}/riscv32-unknown-elf/lib/${multilibdir}/crt0.o
done
mkdir -p ${install_dir}/riscv32-unknown-elf/include/newlib-nano
cp -r ${build_dir}/newlib-nano-inst/include/* ${install_dir}/riscv32-unknown-elf/include/newlib-nano

#======================================================================
# GCC - Stage 2
#======================================================================

__banner Configure GCC - Stage 2

cd ${src_dir}/gcc
./contrib/download_prerequisites
mkdir -p ${build_dir}/gcc-stage2
cd ${build_dir}/gcc-stage2
${src_dir}/gcc/configure                                   \
    --target=riscv32-unknown-elf                        \
    --prefix=${install_dir}                           \
    --with-sysroot=${install_dir}/riscv32-unknown-elf \
    --with-native-system-header-dir=/include		\
    --with-newlib                                       \
    --disable-shared                                    \
    --enable-languages=c,c++                            \
    --enable-tls                                        \
    --disable-werror                                    \
    --disable-libmudflap                                \
    --disable-libssp                                    \
    --disable-libquadmath \
    --disable-libgomp                                   \
    --disable-nls                                       \
    --enable-multilib                                   \
    --with-multilib-generator="rv32e-ilp32e--c rv32ea-ilp32e--m rv32em-ilp32e--c rv32eac-ilp32e-- rv32emac-ilp32e-- rv32i-ilp32--c rv32ia-ilp32--m rv32im-ilp32--c rv32if-ilp32f-rv32ifd-c rv32iaf-ilp32f-rv32imaf,rv32iafc-d rv32imf-ilp32f-rv32imfd-c rv32iac-ilp32-- rv32imac-ilp32-- rv32imafc-ilp32f-rv32imafdc- rv32ifd-ilp32d--c rv32imfd-ilp32d--c rv32iafd-ilp32d-rv32imafd,rv32iafdc- rv32imafdc-ilp32d-- rv64i-lp64--c rv64ia-lp64--m rv64im-lp64--c rv64if-lp64f-rv64ifd-c rv64iaf-lp64f-rv64imaf,rv64iafc-d rv64imf-lp64f-rv64imfd-c rv64iac-lp64-- rv64imac-lp64-- rv64imafc-lp64f-rv64imafdc- rv64ifd-lp64d--m,c rv64iafd-lp64d-rv64imafd,rv64iafdc- rv64imafdc-lp64d--" \
    --with-arch=${DEFAULTARCH}                          \
    --with-abi=${DEFAULTABI}

__banner Building GCC - Stage 2

make -j${PARALLEL}
make install

#======================================================================
exit 0
