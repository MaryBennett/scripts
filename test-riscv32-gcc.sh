#!/usr/bin/env bash
# Script for running tests 

#======================================================================
# Variables
#======================================================================

DEFAULTSRC=${PWD}
TARGET_BOARD=riscv-sim
BASEBOARD=dejagnu/baseboards/${TARGET_BOARD}.exp
OUTPUTDIR=${PWD}/test-output

#======================================================================
# Support functions
#======================================================================

__die()
{
    echo $*
    exit 1
}

__banner()
{
    echo "============================================================"
    echo $*
    echo "============================================================"
}

#======================================================================
# Set source directory for user input
#======================================================================

if [ -n "$1" ]; then
  src_dir=$1
else
  src_dir=${DEFAULTSRC}
fi

#======================================================================
# Build DejaGNU - if needed 1.6.2
#======================================================================

if [ ! "$(dejagnu --version | grep -q '1.6.2')" ]; then
	__banner Download and Install DejaGNU 1.6.2
	mkdir -p /tmp/dejagnu
	cd /tmp/dejagnu
	wget https://ftp.gnu.org/gnu/dejagnu/dejagnu-1.6.2.tar.gz
	tar xf dejagnu-1.6.2.tar.gz
	cd dejagnu-1.6.2
	./configure
	make -j12
	make install
	cd /tmp 
	rm -rf dejagnu
fi

#======================================================================
# Clone DejaGnu (for BASEBOARD)
#======================================================================

cd ${src_dir}

if [ ! -d "${src_dir}/dejagnu" ]; then
  __banner Clone DejaGNU
  git clone https://git.savannah.gnu.org/git/dejagnu.git ${src_dir}/dejagnu
fi

if [ ! -e "${src_dir}/${BASEBOARD}" ]; then
  __die "No ${BASEBOARD}"
fi
__banner "Baseboard at ${BASEBOARD} available"

#======================================================================
# Start Testing
#======================================================================

__banner "Test Output at ${OUTPUTDIR}"
mkdir -p ${OUTPUTDIR}

export PATH=${src_dir}/install/bin:${PATH}

#======================================================================
# Test Binutils
#======================================================================

cd ${src_dir}/build/binutils-gdb
# Requires autoconf?

__banner "Testing GAS"
make check-gas
cp ${src_dir}/build/binutils-gdb/gas/testsuite/gas.log ${OUTPUTDIR}/gas.log
cp ${src_dir}/build/binutils-gdb/gas/testsuite/gas.sum ${OUTPUTDIR}/gas.sum

# Highlight unexpected?
# In gas.sum, if ^FAIL: ; then print line

__banner "Testing LD"
make check-ld
cp ${src_dir}/build/binutils-gdb/ld/ld.log ${OUTPUTDIR}/ld.log
cp ${src_dir}/build/binutils-gdb/ld/ld.sum ${OUTPUTDIR}/ld.sum

#======================================================================
# Test GCC
#======================================================================

cd ${src_dir}/build/gcc-stage2
export RISCV_SIM_COMMAND=riscv-unknown-elf-run
export RISCV_TRIPLE=riscv32-unknown-elf
export DEJAGNU=${src_dir}/${BASEBOARD}

__banner "Testing GCC"
make check-gcc RUNTESTFLAGS="--target_board='${TARGET_BOARD}'"

exit 0
