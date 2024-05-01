#!/bin/bash

set -eou pipefail

# Script settings
APT_INSTALL_CMD="apt-get install -y --no-install-recommends"
LLVM_VERSION=${LLVM_VERSION:-18}
CMAKE_VERSION="3.29.2"
CMAKE_INSTALL_DIR=${CMAKE_INSTALL_DIR:-/usr/local/cmake}
CMAKE_INSTALL_OVERRIDE="0"

# Script variables/parameters
SCRIPT_DIR=$(realpath $(dirname $0))
LINUX_DISTRO=""
LINUX_RELEASE_NUM=""
LINUX_RELEASE_NAME=""
LINUX_RELEASE_NAME_LOWERCASE=""
UBUNTU_TESTING_REPO="ppa:ubuntu-toolchain-r/test"

function usage {
    echo "Usage: $0 [<option> [<option ... ]]"
    echo "Options:"
    echo "   --cmake-install-override : Install CMake and override existing CMake version"
    echo "   --llvm-version <N>       : Set LLVM version to install"
    echo "   --help                   : Display this usage information"
}

function setup_apt_utils {
    # Install lsb-release
    apt-get update && $APT_INSTALL_CMD lsb-release

    # Get distro name (e.g. Ubuntu, Debian)
    LINUX_DISTRO=$(lsb_release -is)

    # Get release name (e.g. Focal, Buster)
    LINUX_RELEASE_NAME=$(lsb_release -cs)
    LINUX_RELEASE_NAME_LOWERCASE=${LINUX_RELEASE_NAME,,}

    # Get release number (e.g. 20.04, 10)
    LINUX_RELEASE_NUM=$(lsb_release -rs)

    # Install add-apt-repository and basic packages
    $APT_INSTALL_CMD software-properties-common gnupg wget
}

function install_llvm_toolchain {
    # Add repo for LLVM
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
    add-apt-repository "deb http://apt.llvm.org/${LINUX_RELEASE_NAME_LOWERCASE}/ llvm-toolchain-${LINUX_RELEASE_NAME_LOWERCASE}-${LLVM_VERSION} main"

    # Update the list of packages
    apt-get update

    # Install LLVM libc++
    $APT_INSTALL_CMD libc++-$LLVM_VERSION-dev libc++abi-$LLVM_VERSION-dev libc++1-$LLVM_VERSION libc++abi1-$LLVM_VERSION libunwind-$LLVM_VERSION

    # Install LLVM tools
    $APT_INSTALL_CMD clang-$LLVM_VERSION clang-format-$LLVM_VERSION clang-tidy-$LLVM_VERSION lld-$LLVM_VERSION lldb-$LLVM_VERSION python3-lldb-$LLVM_VERSION

    # Install compiler-rt for sanitizers and llvm-symbolizer for address sanitizer stack traces
    $APT_INSTALL_CMD llvm-$LLVM_VERSION libclang-rt-$LLVM_VERSION-dev
    update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $(( $LLVM_VERSION * 100 ))

    # Set LLVM tools default version
    $SCRIPT_DIR/llvm_update_alternatives.sh --llvm-version $LLVM_VERSION

    # Install ctcache
    $SCRIPT_DIR/ctcache_install.sh --llvm-version=$LLVM_VERSION
}

# Install GCC.
# libstdc++-10-dev (complementing g++-10) is a C++ runtime providing near complete C++20 support.
# When running on older distributions (Debian 10), don't attempt to install GCC 10,
# to avoid upgrading libc6.
function install_gcc {
    # Install the system default GCC compilers first
    $APT_INSTALL_CMD gcc g++

    GCC_10_PACKAGES="gcc-10 g++-10 libstdc++-10-dev"
    UBUNTU_RELEASE_NUM=${LINUX_RELEASE_NUM%.*} # Remove the fraction part, keeping only major version
    DEBIAN_RELEASE_NUM=${LINUX_RELEASE_NUM}

    # If Ubuntu/Debian version is recent, install GCC 10 from default repos.
    # Otherwise, don't attempt to install it, as it may upgrade the glibc version
    # (libc6 package).
    if [ "${LINUX_DISTRO}" = "Ubuntu" ] && [[ ${UBUNTU_RELEASE_NUM} -ge 20 ]]; then
        $APT_INSTALL_CMD $GCC_10_PACKAGES
        return
    elif [ "${LINUX_DISTRO}" = "Debian" ] && [[ ${DEBIAN_RELEASE_NUM} -ge 11 ]]; then
        $APT_INSTALL_CMD $GCC_10_PACKAGES
        return
    fi
}

function install_testing_packages {
    if ! [ "${LINUX_DISTRO}" = "Ubuntu" ]; then
        echo "Only installing testing packages on Ubuntu (our development distro)."
        return
    fi

    # Setup the testing repository
    add-apt-repository -y "${UBUNTU_TESTING_REPO}"
    apt-get update

    # Install latest gdb version
    $APT_INSTALL_CMD gdb

    # Install latest available cmake from testing package.
    # Ubuntu 20.04 ships with cmake 3.16.3 which is too old.
    if [ "$CMAKE_INSTALL_OVERRIDE" == 0 ]; then
        $APT_INSTALL_CMD cmake
    fi
}

function install_cmake {
    # Set temporary work dir
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    cd $TEMP_DIR

    # Remove previously installed cmake package
    apt-get remove -y cmake cmake-data

    # Download and extract the CMake tarball
    CMAKE_RELEASE_NAME=cmake-${CMAKE_VERSION}-linux-x86_64
    CMAKE_TARBALL=${CMAKE_RELEASE_NAME}.tar.gz
    wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_TARBALL}
    tar -zxvf ${CMAKE_TARBALL}

    # Remove the destination install folder if already exists
    if [ -d ${CMAKE_INSTALL_DIR} ]; then
        echo "Destination ${CMAKE_INSTALL_DIR} exists; removing previous installation."
        rm -r ${CMAKE_INSTALL_DIR}
    fi

    # Move cmake to the destination folder
    mv ${CMAKE_RELEASE_NAME} ${CMAKE_INSTALL_DIR}

    # Make this the default cmake
    MAX_PRIORITY=2147483647
    update-alternatives --install /usr/bin/cmake cmake ${CMAKE_INSTALL_DIR}/bin/cmake $MAX_PRIORITY
}

function parse_args {
    # Check for support script options in the begining of the command line.
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --help)
                usage
                exit 0
                ;;
            --cmake-install-override)
                CMAKE_INSTALL_OVERRIDE="1"
                ;;
            --llvm-version)
                shift;
                LLVM_VERSION=$1
                ;;
            *)  echo "Error: unknown argument: $OPT"
                usage
                exit 1
                ;;
        esac
        shift
    done

    NUMBER_REGEX='^[0-9]+$'
    if ! [[ $LLVM_VERSION =~ $NUMBER_REGEX ]]; then
        echo "Error: invalid LLVM version specified: $LLVM_VERSION"
        usage
        exit 1
    else
        echo "LLVM version to install: $LLVM_VERSION"
    fi
}

function main {
    parse_args $@

    if [ `id -u` != 0 ] ; then
        echo "Must be run as root!"
        exit 1
    fi

    export DEBIAN_FRONTEND=noninteractive

    setup_apt_utils

    # Install basic packages and utilities
    $APT_INSTALL_CMD coreutils curl git jq rsync unzip patch parallel p7zip-full

    # Install build tools for Arrow (UCX)
    $APT_INSTALL_CMD autoconf automake ccache make ninja-build libtool

    # Install the LLVM toolchain
    install_llvm_toolchain

    # Install GCC compilers
    install_gcc

    # Download and install recent CMake
    if [ "$CMAKE_INSTALL_OVERRIDE" == "1" ]; then
        install_cmake
    fi

    # Install testing packages, such as latest GDB.
    # It is done last since it requires setting up testing repositories.
    install_testing_packages

    # Cleanup
    apt autoremove -y

    # Print the GLIBC version
    ldd --version

    echo "========================================"
    echo "Done installing C++ devtools."
    echo "========================================"
}

main $@
