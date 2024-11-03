#!/bin/bash

# This script installs the cppcheck project - C++ static analyzer.
# https://cppcheck.sourceforge.io

set -euo pipefail

SCRIPT_DIR="$(realpath $(dirname $0))"
CPPCHECK_GIT_TAG=88874998d0ed4ddba0f301deb21ea33efc9203ae # 2.15.0
FORCE=""
INSTALL_DEPS=1
CMAKE_ROOT_DIR=${CMAKE_ROOT_DIR:-/usr/local/cmake}

function usage {
    echo "Usage: $0 [--force][--no-install-deps][--help]"
    echo
    echo "Install cppcheck."
}

function parse_args {
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --force) shift; FORCE=1;;
            --no-install-deps) shift; INSTALL_DEPS=0;;
            --help) usage; exit 0;;
            *) echo "Error: unknown argument: $1"; usage; exit 1;;
        esac
    done
}

function prepare {
    # Make sure this script is run as root with sudo.
    if [[ $EUID -ne 0 ]]; then
        echo "Please run this script as root with sudo."
        exit 1
    fi

    # Detect the Linux OS and set package manager commands
    source $SCRIPT_DIR/linux_distro_detect.sh

    # Install the which package if it exists.
    # The which command is not available by default on all Linux distributions.
    (set +e; $INSTALL_CMD which 2>/dev/null || true)

    CPPCHECK_EXE=$(which cppcheck || true)
    if [ ! -z ${CPPCHECK_EXE} ] && [ -z ${FORCE} ]; then
        echo "cppcheck found in ${CPPCHECK_EXE}. Add --force for re-installation."
        exit 0
    fi
}

function install_deps {
    export DEBIAN_FRONTEND=noninteractive

    # Install prerequisite packages
    $UPDATE_CMD
    $INSTALL_CMD ca-certificates curl make unzip

    # Install gcc 10.
    # Don't attempt to install gcc 10 on Debian, as it can bump the glibc version.
    if [ $LINUX_DISTRO = "centos" ]; then
        $INSTALL_CMD centos-release-scl
        $INSTALL_CMD devtoolset-10-gcc devtoolset-10-gcc-c++
    elif [[ $LINUX_DISTRO = "almalinux" || $LINUX_DISTRO = "rocky" ]]; then
        $INSTALL_CMD gcc-toolset-10-gcc gcc-toolset-10-gcc-c++
    else
        $INSTALL_CMD gcc g++
    fi

    # Install recent CMake
    $SCRIPT_DIR/cmake_install.sh
}

function install_cppcheck {
    # Create temp dir
    CPPCHECK_TEMP_DIR=$(mktemp -d -t cppcheck-temp-XXXXXX)
    trap "rm -rf $CPPCHECK_TEMP_DIR" EXIT

    set -x

    # Download cppcheck sources
    cd $CPPCHECK_TEMP_DIR
    curl -L https://github.com/danmar/cppcheck/archive/$CPPCHECK_GIT_TAG.zip -o $CPPCHECK_GIT_TAG.zip
    unzip $CPPCHECK_GIT_TAG.zip

    # Configure
    mkdir build && cd build
    CPPCHECK_SRC_DIR=$(realpath ../cppcheck-$CPPCHECK_GIT_TAG)
    CFGDIR="/usr/local/share/Cppcheck"
    CONFIGURE_COMMAND="$CMAKE_ROOT_DIR/bin/cmake $CPPCHECK_SRC_DIR -DFILESDIR=${CFGDIR} -DBUILD_GUI=0 -DBUILD_TESTS=0 -DDISABLE_DMAKE=1 -DCMAKE_CXX_COMPILER=g++"
    echo $CONFIGURE_COMMAND > $CPPCHECK_TEMP_DIR/configure.sh
    chmod +x $CPPCHECK_TEMP_DIR/configure.sh
    if [ $LINUX_DISTRO = "centos" ]; then
        scl enable devtoolset-10 "bash -c $CPPCHECK_TEMP_DIR/configure.sh"
    elif [[ $LINUX_DISTRO = "almalinux" || $LINUX_DISTRO = "rocky" ]]; then
        scl enable gcc-toolset-10 "bash -c $CPPCHECK_TEMP_DIR/configure.sh"
    else
        $CONFIGURE_COMMAND
    fi

    # Build and install
    make -j
    make install CFGDIR=${CFGDIR}

    set +x
}

function main {
    parse_args $@
    prepare
    if [ ${INSTALL_DEPS} = 1 ]; then
        install_deps
    fi
    install_cppcheck
    echo "cppcheck successfully installed."
}

main $@
