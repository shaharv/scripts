#!/bin/bash

# Script for building GCC 10 from source.
# The purpose of building the compiler from source is to use the original
# libc version of the host Linux OS. For example, when building on Debian 10,
# the resulting GCC binaries will the compatible with the host glibc version,
# GLIBC_2.28. OTOH, when installing GCC 10 from package on Debian 10, the
# glibc version will be bumped.

set -euo pipefail

SCRIPT_DIR="$(realpath $(dirname $0))"
GCC_VERSION=${GCC_VERSION:-gcc-10.5.0}
SRC_TARGET_DIR=${SRC_TARGET_DIR:-/usr/local/src}
BUILD_DIR=${BUILD_DIR:-$SRC_TARGET_DIR/$GCC_VERSION/build}
INSTALL_ROOT_DIR=${INSTALL_ROOT_DIR:-/opt}
INSTALL_DIR=${INSTALL_ROOT_DIR}/${GCC_VERSION}
FORCE_DOWNLOAD="0"
SET_AS_DEFAULT="0"
KEEP_FILES="0"
SKIP_DEPS_INSTALL="0"

function usage {
    echo "Usage: $0 [--force-download] [--set-as-default] [--keep-files] [--skip-deps-install]"
    echo
    echo "Build and install GCC C/C++ compilers from source."
}

function parse_args {
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --force-download) shift; FORCE_DOWNLOAD="1";;
            --set-as-default) shift; SET_AS_DEFAULT="1";;
            --skip-deps-install) shift; SKIP_DEPS_INSTALL="1";;
            --keep-files) shift; KEEP_FILES="1";;
            --help) usage; exit 0;;
            *) echo "Error: unknown argument: $1"; usage; exit 1;;
        esac
    done
}

function prepare {
    # Make sure this script is run as root with sudo, if packages are to be installed.
    if [ "$SKIP_DEPS_INSTALL" = "0" ] && [[ $EUID -ne 0 ]]; then
        echo "Please run this script as root with sudo."
        exit 1
    fi

    # Detect the Linux OS and set package manager commands
    source $SCRIPT_DIR/linux_distro_detect.sh

    mkdir -p $INSTALL_DIR
}

function prepare_gcc_artifacts {
    GCC_TARBALL=$GCC_VERSION.tar.gz
    cd $SRC_TARGET_DIR
    if [ "$FORCE_DOWNLOAD" = "1" ]; then
        rm -f $GCC_TARBALL
    fi
    if [ "$KEEP_FILES" = "0" ]; then
        trap "rm -f $SRC_TARGET_DIR/$GCC_TARBALL" EXIT
    fi
    if [ ! -e $GCC_TARBALL ]; then
        wget https://ftp.gnu.org/gnu/gcc/$GCC_VERSION/$GCC_TARBALL
    fi
    tar -xf $GCC_VERSION.tar.gz
    cd $GCC_VERSION
    ./contrib/download_prerequisites
}

function install_gcc_deps {
    if [ "$SKIP_DEPS_INSTALL" = "1" ]; then
        return
    fi
    export DEBIAN_FRONTEND=noninteractive
    $UPDATE_CMD
    # Install script dependencies
    $INSTALL_CMD wget ca-certificates
    # Install GCC dependencies
    $INSTALL_CMD build-essential libgmp-dev libmpfr-dev libmpc-dev flex bison texinfo
}

function build_gcc {
    if [ "$KEEP_FILES" = "0" ]; then
        trap "rm -rf $BUILD_DIR" EXIT
    fi
    # Configure and build GCC
    mkdir -p $BUILD_DIR && cd $BUILD_DIR
    ../configure --prefix=$INSTALL_DIR --enable-languages=c,c++ --disable-multilib --enable-optimize-stdlib
    make -j $(nproc)
}

function install_gcc {
    cd $BUILD_DIR
    make install
    # Verify the built GCC binaries
    $INSTALL_DIR/bin/gcc --version
    $INSTALL_DIR/bin/g++ --version
}

function set_default_gcc {
    if [ "$SET_AS_DEFAULT" = 0 ]; then
        return
    fi
    MAX_PRIORITY=2147483647
    update-alternatives --install /usr/bin/gcc gcc $INSTALL_DIR/bin/gcc $MAX_PRIORITY --slave /usr/bin/g++ g++ $INSTALL_DIR/bin/g++
}

function create_gcc_tarball {
    TAR_FILE=$GCC_VERSION.tar.gz
    cd $INSTALL_ROOT_DIR
    tar -czvf $TAR_FILE $GCC_VERSION
    echo "Created GCC tarball $TAR_FILE."
}

function main {
    parse_args $@
    prepare
    echo "About to build and install GCC ($GCC_VERSION)."
    install_gcc_deps
    prepare_gcc_artifacts
    build_gcc
    install_gcc
    set_default_gcc
    create_gcc_tarball
    echo "GCC successfully installed ($GCC_VERSION)."
}

main $@
