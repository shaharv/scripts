#!/bin/bash

set -eou pipefail

SCRIPT_DIR="$(realpath $(dirname $0))"
CMAKE_VERSION=${CMAKE_VERSION:-"3.29.4"}
CMAKE_INSTALL_DIR=${CMAKE_INSTALL_DIR:-/usr/local/cmake}
FORCE="0"

function usage {
    echo "Usage: $0 [<option> [<option ... ]]"
    echo "Options:"
    echo "   --force  : Force install CMake and override existing CMake version"
    echo "   --help   : Display this usage information"
}

function should_install_cmake {
    # If CMake is already installed, check its version.
    if [ ! -z $(which cmake 2>/dev/null) ]; then
        # Find the CMake version and remove the first two dots.
        # CMake version has the format X.Y.Z. On rare cases, there could be a 4th digit, X.Y.Z.W.
        # For comparing as floats, only the two first digits are removed.
        CMAKE_INSTALLED_VERSION=$(cmake --version | grep "cmake version" | sed 's/cmake version //')
        CMAKE_INSTALLED_VERSION_AS_FLOAT=$(echo $CMAKE_INSTALLED_VERSION | sed 's/\.//' | sed 's/\.//')
        CMAKE_VERSION_AS_FLOAT=$(echo $CMAKE_VERSION | sed 's/\.//' | sed 's/\.//')
        CMAKE_IS_NEW=$(echo "$CMAKE_INSTALLED_VERSION_AS_FLOAT >= $CMAKE_VERSION_AS_FLOAT" | bc)
        # If the installed CMake version is equal or newer to the to-be-installed version, skip the installation.
        if [ $CMAKE_IS_NEW -eq 1 ]; then
            echo "CMake $CMAKE_INSTALLED_VERSION detected, which is equal or newer to $CMAKE_VERSION."
            if [ $FORCE = "1" ]; then
                echo "Installing CMake since --force was specified."
            else
                echo "Skipping installation."
                return 0
            fi
        else
            echo "CMake $CMAKE_INSTALLED_VERSION detected, which is older than $CMAKE_VERSION - proceeding with installation."
        fi
    fi
    return 1
}

function install_cmake {
    # Set temporary work dir
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    cd $TEMP_DIR

    # Remove previously installed cmake package
    $REMOVE_CMD cmake cmake-data

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

    # Make this the default cmake on Debian based systems
    if [ $LINUX_DISTRO != "centos" ]; then
        MAX_PRIORITY=2147483647
        update-alternatives --install /usr/bin/cmake cmake ${CMAKE_INSTALL_DIR}/bin/cmake $MAX_PRIORITY
    fi

    echo "CMake installed to $CMAKE_INSTALL_DIR."
}

function parse_args {
    # Check for support script options in the beginning of the command line.
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --help)
                usage
                exit 0
                ;;
            --force)
                FORCE="1"
                ;;
            *)  echo "Error: unknown argument: $OPT"
                usage
                exit 1
                ;;
        esac
        shift
    done
}

function main {
    parse_args $@

    if [ `id -u` != 0 ]; then
        echo "Must be run as root!"
        exit 1
    fi

    source $SCRIPT_DIR/linux_distro_detect.sh

    export DEBIAN_FRONTEND=noninteractive

    $UPDATE_CMD
    $INSTALL_CMD wget ca-certificates bc
    if [ $LINUX_DISTRO = "centos" ]; then
        $INSTALL_CMD which
    fi

    set +e
    should_install_cmake
    SHOULD_INSTALL=$?
    set -e
    if [ $SHOULD_INSTALL -eq 1 ]; then
        install_cmake
    fi
}

main $@
