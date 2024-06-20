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
    echo "   --core-only              : Install the basic set of common packages"
    echo "   --help                   : Display this usage information"
    echo "   --llvm-version <N>       : Set LLVM version to install"
}

function setup_apt_utils {
    # Install lsb-release
    $UPDATE_CMD && $INSTALL_CMD lsb-release

    # Get release name (e.g. Focal, Buster)
    LINUX_RELEASE_NAME=$(lsb_release -cs)
    LINUX_RELEASE_NAME_LOWERCASE=${LINUX_RELEASE_NAME,,}

    # Get release number (e.g. 20.04, 10)
    LINUX_RELEASE_NUM=$(lsb_release -rs)

    # Install add-apt-repository and basic packages
    $INSTALL_CMD software-properties-common gnupg
}

# Install GCC.
# libstdc++-10-dev (complementing g++-10) is the minimal GNU C++ runtime providing almost full C++20 support.
# When running on older distributions (Debian 10), don't attempt to install GCC 10,
# to avoid upgrading libc6.
function install_gcc {
    if [ "${LINUX_DISTRO}" = "centos" ]; then
        # After installing gcc toolchain on CentOS, it should be set to use gcc-10 with the
        # following command: "scl enable devtoolset-10 bash"
        $INSTALL_CMD centos-release-scl
        $INSTALL_CMD devtoolset-10-gcc devtoolset-10-gcc-c++
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
    add-apt-repository -y "${UBUNTU_TESTING_REPO}"
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
    add-apt-repository "deb http://apt.llvm.org/${LINUX_RELEASE_NAME_LOWERCASE}/ llvm-toolchain-${LINUX_RELEASE_NAME_LOWERCASE}-${LLVM_VERSION} main"

    # Update the list of packages
    $UPDATE_CMD

    # Install compiler-rt for sanitizers and llvm-symbolizer for address sanitizer stack traces.
    # The "|| true" is added to avoid failing on llvm-12, where libclang-rt is not available.
    $INSTALL_CMD llvm-$LLVM_VERSION libclang-rt-$LLVM_VERSION-dev || true
    update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $(( $LLVM_VERSION * 100 ))

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

    if [ `id -u` != 0 ] ; then
        echo "Must be run as root!"
        exit 1
    fi

    # Get distro ID (e.g. ubuntu, debian, centos)
    LINUX_DISTRO=$(grep "\bID\=" /etc/os-release | sed s/^ID\=// | tr -d '"')

    echo "Installing packages for $LINUX_DISTRO."

    if [ $LINUX_DISTRO = "centos" ]; then
        INSTALL_CMD="yum install -y"
        UPDATE_CMD="yum update -y"
        REMOVE_CMD="yum remove -y"
        AUTOREMOVE_CMD="yum autoremove -y"
    else
        INSTALL_CMD="apt-get install -y --no-install-recommends"
        UPDATE_CMD="apt-get update -y"
        REMOVE_CMD="apt-get remove -y"
        AUTOREMOVE_CMD="apt-get autoremove -y"

        export DEBIAN_FRONTEND=noninteractive
        echo "LLVM version to install: $LLVM_VERSION"
    fi

    $UPDATE_CMD

    # Install basic build packages and libraries
    $INSTALL_CMD \
        ccache \
        cmake \
        coreutils \
        curl \
        jq \
        rsync \
        make \
        net-tools \
        netcat \
        ninja-build \
        parallel \
        unzip

    if [ $LINUX_DISTRO = "centos" ]; then
        $INSTALL_CMD epel-release
    else
        setup_apt_utils
    fi

    if [ $LINUX_DISTRO = "centos" ]; then
        $INSTALL_CMD \
            binutils-devel \
            numactl-devel \
            openssl-devel \
            p7zip \
            which \
            zlib-devel
    else
        $INSTALL_CMD \
            binutils-dev \
            libnuma-dev \
            libcurl4-openssl-dev \
            libssl-dev \
            libz-dev \
            p7zip-full
    fi

    # Install the LLVM toolchain on Ubuntu/Debian.
    # On CentOS, skip LLVM installation, as nightly LLVM packages are not available for CentOS.
    # When CORE_ONLY is set, only install the LLVM runtime libraries and llvm-symbolizer.
    if [ $LINUX_DISTRO != "centos" ]; then
        install_llvm
    fi

    if [ "$CORE_ONLY" == "1" ]; then
        return
    fi

    # Install misc. packages for build and CI
    $INSTALL_CMD doxygen git patch p7zip-full python-yaml

    # Install build packages for Arrow (UCX)
    $INSTALL_CMD autoconf libtool automake

    # Install GCC compilers
    install_gcc

    # Download and install recent CMake
    if [ "$CMAKE_INSTALL_OVERRIDE" == "1" ]; then
        $SCRIPT_DIR/cmake_install.sh
    fi

    # Install testing packages, such as latest GDB.
    # It is done last since it requires setting up testing repositories.
    install_testing_packages

    # Install pip3 and extra python packages.
    $INSTALL_CMD python3-pip
    pip3 install codespell pyyaml

    # Install cppcheck
    $SCRIPT_DIR/cppcheck_install.sh
}

main $@
finish
