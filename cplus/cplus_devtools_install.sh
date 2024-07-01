#!/bin/bash

set -eou pipefail

# Script settings
CORE_ONLY="0"
INSTALL_CMD=""
UPDATE_CMD=""
REMOVE_CMD=""
AUTOREMOVE_CMD=""
LLVM_VERSION=18
CMAKE_INSTALL_OVERRIDE="0"
CPPCHECK_SKIP="0"

# Script variables/parameters
SCRIPT_DIR=$(realpath $(dirname $0))
LINUX_DISTRO=""
LINUX_RELEASE_NUM=""
LINUX_RELEASE_NAME=""

function usage {
    echo "Usage: $0 [<option> [<option ... ]]"
    echo "Options:"
    echo "   --cmake-install-override : Install CMake and override existing CMake version"
    echo "   --core-only              : Install the basic set of common packages"
    echo "   --cppcheck-skip          : Do not install cppcheck"
    echo "   --help                   : Display this usage information"
    echo "   --llvm-version <N>       : Set LLVM version to install"
}

# Install GCC.
# libstdc++-10-dev (complementing g++-10) is the minimal GNU C++ runtime providing almost full C++20 support.
# When running on older Debian distributions, don't attempt to install GCC 10,
# to avoid upgrading libc6.
function install_gcc {
    if [ "${LINUX_DISTRO}" = "centos" ]; then
        # After installing gcc 10 toolchain on CentOS, enable it with the
        # following command: "scl enable devtoolset-10 bash"
        $INSTALL_CMD centos-release-scl
        $INSTALL_CMD devtoolset-10-gcc devtoolset-10-gcc-c++
    elif [ "${LINUX_DISTRO}" = "almalinux" ]; then
        # After installing gcc 10 toolchain on AlmaLinux, enable it with the
        # following command: "scl enable gcc-toolset-10 bash"
        $INSTALL_CMD gcc-toolset-10-gcc gcc-toolset-10-gcc-c++
    else
        # Install the system default GCC compilers first
        $INSTALL_CMD gcc g++

        GCC_10_PACKAGES="gcc-10 g++-10 libstdc++-10-dev"
        UBUNTU_RELEASE_NUM=${LINUX_RELEASE_NUM%.*} # Remove the fraction part, keeping only major version
        DEBIAN_RELEASE_NUM=${LINUX_RELEASE_NUM}

        # If Ubuntu/Debian version is recent, install GCC 10 from default repos.
        # Otherwise, don't attempt to install it, as it may upgrade the glibc version
        # (libc6 package).
        if [ "${LINUX_DISTRO}" = "ubuntu" ] && [[ ${UBUNTU_RELEASE_NUM} -ge 20 ]]; then
            $INSTALL_CMD $GCC_10_PACKAGES
            return
        elif [ "${LINUX_DISTRO}" = "debian" ] && [[ ${DEBIAN_RELEASE_NUM} -ge 11 ]]; then
            $INSTALL_CMD $GCC_10_PACKAGES
            return
        fi
    fi
}

function install_testing_packages {
    if ! [ "${LINUX_DISTRO}" = "ubuntu" ]; then
        echo "Only installing testing packages on Ubuntu (our development distro)."
        return
    fi

    # Setup the testing repository
    add-apt-repository -y ppa:ubuntu-toolchain-r/test
    $UPDATE_CMD

    # Install latest gdb version
    $INSTALL_CMD gdb

    # Install latest available cmake from testing package.
    # Ubuntu 20.04 ships with cmake 3.16.3 which is too old.
    if [ "$CMAKE_INSTALL_OVERRIDE" == 0 ]; then
        $INSTALL_CMD cmake
    fi
}

function install_llvm {
    # Add repo for LLVM
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
    add-apt-repository -y "deb http://apt.llvm.org/${LINUX_RELEASE_NAME}/ llvm-toolchain-${LINUX_RELEASE_NAME}-${LLVM_VERSION} main"

    # Update the list of packages
    $UPDATE_CMD

    # Install compiler-rt for sanitizers and llvm-symbolizer for address sanitizer stack traces.
    # The "|| true" is added to avoid failing on llvm-12, where libclang-rt is not available.
    $INSTALL_CMD llvm-$LLVM_VERSION libclang-rt-$LLVM_VERSION-dev || true
    update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $(( $LLVM_VERSION * 100 )) || true

    if [ "$CORE_ONLY" == "1" ]; then
        return
    fi

    # Install LLVM libc++
    $INSTALL_CMD libc++-$LLVM_VERSION-dev libc++abi-$LLVM_VERSION-dev libc++1-$LLVM_VERSION libc++abi1-$LLVM_VERSION libunwind-$LLVM_VERSION

    # Install LLVM tools
    $INSTALL_CMD clang-$LLVM_VERSION clang-format-$LLVM_VERSION clang-tidy-$LLVM_VERSION lld-$LLVM_VERSION lldb-$LLVM_VERSION python3-lldb-$LLVM_VERSION

    # Set LLVM tools default version
    $SCRIPT_DIR/llvm_update_alternatives.sh --llvm-version $LLVM_VERSION

    # Install ctcache
    $SCRIPT_DIR/ctcache_install.sh --llvm-version=$LLVM_VERSION
}

function parse_args {
    # Check for supported script options in the beginning of the command line.
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
            --core-only)
                CORE_ONLY="1"
                ;;
            --cppcheck-skip)
                CPPCHECK_SKIP="1"
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
    fi
}

function finish {
    # Cleanup
    $AUTOREMOVE_CMD

    # Print the GLIBC version
    ldd --version

    echo "========================================"
    echo "Done installing C++ devtools."
    echo "========================================"
}

function main {
    parse_args $@

    if [ `id -u` != 0 ]; then
        echo "Must be run as root!"
        exit 1
    fi

    source $SCRIPT_DIR/linux_distro_detect.sh

    echo "Installing packages for $LINUX_DISTRO."
    echo "LLVM version to install: $LLVM_VERSION"

    export DEBIAN_FRONTEND=noninteractive

    $UPDATE_CMD

    if [[ $LINUX_DISTRO = "centos" || $LINUX_DISTRO = "almalinux" ]]; then
        $INSTALL_CMD epel-release
        if [ $LINUX_DISTRO = "almalinux" ]; then
            yum config-manager --set-enabled powertools
        fi
        $UPDATE_CMD
    else
        # Install add-apt-repository and basic packages
        $UPDATE_CMD && $INSTALL_CMD software-properties-common gnupg lsb-release
    fi

    # Install basic build packages and libraries
    $INSTALL_CMD \
        bc \
        ca-certificates \
        ccache \
        cmake \
        coreutils \
        curl \
        jq \
        rsync \
        make \
        net-tools \
        ninja-build \
        parallel \
        unzip \
        wget

    if [[ $LINUX_DISTRO = "centos" || $LINUX_DISTRO = "almalinux" ]]; then
        $INSTALL_CMD \
            binutils-devel \
            netcat \
            numactl-devel \
            openssl-devel \
            p7zip \
            which \
            zlib-devel
    else
        $INSTALL_CMD \
            binutils-dev \
            netcat-openbsd \
            libnuma-dev \
            libcurl4-openssl-dev \
            libssl-dev \
            libz-dev \
            p7zip-full
    fi

    # Install the LLVM toolchain on Ubuntu/Debian 10.
    # On CentOS, we skip LLVM installation, as nightly LLVM packages are not available for CentOS.
    # When CORE_ONLY is set, only install the LLVM runtime libraries and llvm-symbolizer.
    if [[ $LINUX_DISTRO = "ubuntu" ]] || [[ $LINUX_DISTRO = "debian" && $LINUX_RELEASE_NUM -eq 10 ]]; then
        install_llvm
    elif [[ $LINUX_DISTRO = "almalinux" ]]; then
        # Install LLD linker. Even if LLVM is not installable from LLVM nightly repos, install
        # LLD as it avoid out of memory crashes of LD.
        $INSTALL_CMD lld
    fi

    if [ "$CORE_ONLY" == "1" ]; then
        return
    fi

    # Install misc. packages for build and CI
    $INSTALL_CMD doxygen git patch python3-yaml

    # Install build packages for Arrow (UCX)
    $INSTALL_CMD autoconf libtool automake

    # Install GCC compilers
    install_gcc

    # Download and install recent CMake
    if [ "$CMAKE_INSTALL_OVERRIDE" = "1" ]; then
        $SCRIPT_DIR/cmake_install.sh
    fi

    # Install testing packages, such as latest GDB.
    # It is done last since it requires setting up testing repositories.
    install_testing_packages

    # Install pip3 and extra python packages.
    $INSTALL_CMD python3-pip
    pip3 install codespell pyyaml

    # Install cppcheck
    if [ "$CPPCHECK_SKIP" = "0" ]; then
        $SCRIPT_DIR/cppcheck_install.sh
    fi
}

main $@
finish
