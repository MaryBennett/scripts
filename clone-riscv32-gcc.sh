#!/usr/bin/env bash
# Script for cloning sources required to build a RISC-V GNU Toolchain

#======================================================================
# Variables
#======================================================================
DEFAULTSRC=${PWD}

#======================================================================
# Support functions
#======================================================================

#======================================================================
# Set source directory for user input
#======================================================================

if [ -n "$1" ]; then
  src_dir=$1
else
  src_dir=${DEFAULTSRC}
fi

#======================================================================
# Clone sources
#======================================================================

if [ ! -d "${src_dir}/binutils-gdb" ]; then
  git clone git://sourceware.org/git/binutils-gdb.git ${src_dir}/binutils-gdb
fi

if [ ! -d "${src_dir}/gcc" ]; then
  git clone git://sourceware.org/git/gcc.git ${src_dir}/gcc
fi

if [ ! -d "${src_dir}/newlib" ]; then
  git clone git://sourceware.org/git/newlib-cygwin.git ${src_dir}/newlib
fi

echo "Sources cloned to ${src_dir}"
#exit 0
