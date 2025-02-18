#!/usr/bin/env bash
# Script for running tests 

#======================================================================
# Variables
#======================================================================

DEFAULTSRC=${PWD}
BASEBOARD=riscv-sim.exp
BASEBOARDDIR=dejagnu/baseboards/${BASEBOARD}

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
# Build DejaGNU - if needed
#======================================================================

# if dejagnu --version isn't dejagnu-1.6.2...
__banner Download and Install DejaGNU
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

#======================================================================
# Clone DejaGnu
#======================================================================

cd ${src_dir}

if [ ! -d "${src_dir}/dejagnu" ]; then
  __banner Clone DejaGNU
  git clone https://git.savannah.gnu.org/git/dejagnu.git ${src_dir}/dejagnu
fi

if [ ! -e "${src_dir}/${BASEBOARDIR}" ]; then
  __die "No ${BASEBOARDDIR}"
fi

exit 0
