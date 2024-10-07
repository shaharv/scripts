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
LLVM_SKIP="0"
GCC_SKIP="0"
CERTS_PATH=""

# Script variables/parameters
SCRIPT_DIR=$(realpath $(dirname $0))
LINUX_DISTRO=""
LINUX_RELEASE_NUM=""
LINUX_RELEASE_NAME=""

function usage {
    echo "Usage: $0 [<option> [<option ... ]]"
    echo "Options:"
    echo "   --certs-install <path>   : Copy certificates from the specified path and install them"
    echo "   --cmake-install-override : Install CMake and override existing CMake version"
    echo "   --core-only              : Install the basic set of common packages"
    echo "   --cppcheck-skip          : Do not install cppcheck"
    echo "   --gcc-skip               : Do not install GCC"
    echo "   --help                   : Display this usage information"
    echo "   --llvm-skip              : Do not install LLVM"
    echo "   --llvm-version <N>       : Set LLVM version to install"
}

# Install GCC.
# libstdc++-10-dev (complementing g++-10) is the minimal GNU C++ runtime providing almost full C++20 support.
# When running on older Ubuntu/Debian distributions, don't attempt to install GCC 10,
# to avoid upgrading libc6.
function install_gcc {
    echo "Installing GCC..."
    if [ "${LINUX_DISTRO}" = "centos" ]; then
        # After installing gcc 10 toolchain on CentOS, enable it with the
        # following command: "scl enable devtoolset-10 bash"
        $INSTALL_CMD centos-release-scl
        $INSTALL_CMD devtoolset-10-gcc devtoolset-10-gcc-c++
    elif [ "${LINUX_DISTRO}" = "almalinux" ]; then
        # After installing gcc 10 toolchain on AlmaLinux, enable it with the
        # following command: "scl enable gcc-toolset-10 bash"
        $INSTALL_CMD gcc-toolset-10-gcc gcc-toolset-10-gcc-c++
    elif { [ "${LINUX_DISTRO}" = "ubuntu" ] && [[ ${LINUX_RELEASE_NUM_MAJOR} -ge 20 ]]; } ||
         { [ "${LINUX_DISTRO}" = "debian" ] && [[ ${LINUX_RELEASE_NUM_MAJOR} -ge 11 ]]; }; then
        # Install gcc 10 apt packages. On Ubuntu >= 20.04 and Debian >= 11, this won't
        # trigger libc6 and libstdc++6 upgrade.
        $INSTALL_CMD gcc-10 g++-10
    else
        # Install the system default GCC compilers
        $INSTALL_CMD gcc g++
    fi
}

function install_testing_packages {
    if ! [ "${LINUX_DISTRO}" = "ubuntu" ]; then
        echo "Skipping testing packages - only installed on Ubuntu."
        return
    fi

    # Setup the testing repository
    add-apt-repository -y ppa:ubuntu-toolchain-r/test
    $UPDATE_CMD

    # Install latest gdb version
    $INSTALL_CMD gdb
}

function install_llvm {
    # Add repo for LLVM
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
    add-apt-repository -y "deb http://apt.llvm.org/${LINUX_RELEASE_NAME}/ llvm-toolchain-${LINUX_RELEASE_NAME}-${LLVM_VERSION} main"

    # Update the list of packages
    $UPDATE_CMD

    # Install compiler-rt for sanitizers and llvm-symbolizer for address sanitizer stack traces.
    # The "|| true" is added to avoid failing on llvm-12, where libclang-rt is not available.
    $INSTALL_CMD llvm-$LLVM_VERSION libclang-rt-$LLVM_VERSION-dev libunwind-$LLVM_VERSION || true
    update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $(( $LLVM_VERSION * 100 )) || true

    if [ "$CORE_ONLY" = "1" ]; then
        return
    fi

    # Install LLVM libc++
    $INSTALL_CMD libc++-$LLVM_VERSION-dev libc++abi-$LLVM_VERSION-dev

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
            --certs-install)
                shift;
                CERTS_PATH=$1
                if [ ! -d "$CERTS_PATH" ]; then
                    echo "$CERTS_PATH is not a folder. Skipping certs installation."
                    CERTS_PATH=""
                fi
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
            --gcc-skip)
                GCC_SKIP="1"
                ;;
            --llvm-skip)
                LLVM_SKIP="1"
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
    else # Debian based
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
        make \
        net-tools \
        ninja-build \
        parallel \
        rsync \
        unzip \
        wget

    if [[ $LINUX_DISTRO = "centos" || $LINUX_DISTRO = "almalinux" ]]; then
        $INSTALL_CMD \
            binutils-devel \
            boost-devel \
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
            libboost-dev \
            libnuma-dev \
            libcurl4-openssl-dev \
            libssl-dev \
            libz-dev \
            p7zip-full
    fi

    if [ "$CERTS_PATH" != "" ]; then
        echo "Installing certificates..."
        if [[ $LINUX_DISTRO = "centos" || $LINUX_DISTRO = "almalinux" ]]; then
            cp $CERTS_PATH/*.crt /etc/pki/ca-trust/source/anchors
            update-ca-trust
        else
            cp -r $CERTS_PATH /usr/local/share/ca-certificates
            update-ca-certificates
        fi
    fi

    # Install the LLVM toolchain on Ubuntu/Debian 10.
    # On CentOS, we skip LLVM installation, as nightly LLVM packages are not available for CentOS.
    # When CORE_ONLY is set, only install the LLVM runtime libraries and llvm-symbolizer.
    if [[ $LINUX_DISTRO = "ubuntu" ]] || [[ $LINUX_DISTRO = "debian" && $LINUX_RELEASE_NUM -eq 10 ]]; then
        if [ "$LLVM_SKIP" = "0" ]; then
            install_llvm
        else
            echo "Skipping LLVM installation are requested."
        fi
    elif [[ $LINUX_DISTRO = "almalinux" ]]; then
        # Install LLD linker. Even if LLVM is not installable from LLVM nightly repos, install
        # LLD as it avoid out of memory crashes of LD.
        $INSTALL_CMD lld
    fi

    # Install misc. packages for build and CI
    $INSTALL_CMD git patch python3-yaml

    # Install build packages for Arrow (UCX)
    $INSTALL_CMD autoconf libtool automake

    if [ "$CORE_ONLY" == "1" ]; then
        return
    fi

    # Install GCC compilers
    if [ "$GCC_SKIP" = "0" ]; then
        install_gcc
    fi

    # Download and install recent CMake
    if [ "$CMAKE_INSTALL_OVERRIDE" = "1" ]; then
        $SCRIPT_DIR/cmake_install.sh
    fi

    # Install pip3 and extra python packages
    $INSTALL_CMD python3-pip
    pip3 install codespell pyyaml

    # Install doxygen
    $INSTALL_CMD doxygen

    # Install cppcheck
    if [ "$CPPCHECK_SKIP" = "0" ]; then
        $SCRIPT_DIR/cppcheck_install.sh
    fi

    # Install testing packages, such as latest GDB.
    # It is done last since it requires setting up testing repositories.
    install_testing_packages
}

main $@
finish
