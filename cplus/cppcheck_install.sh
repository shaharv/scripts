#!/bin/bash

# This script installs the cppcheck project - C++ static analyzer.
# https://cppcheck.sourceforge.io

set -euo pipefail

CPPCHECK_GIT_TAG=2.14.0
FORCE=""

function usage {
    echo "Usage: $0 [--force][--help]"
    echo
    echo "Install cppcheck."
}

function parse_args {
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --force) shift; FORCE=1;;
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

    CPPCHECK_EXE=$(which cppcheck || true)
    if [ ! -z ${CPPCHECK_EXE} ] && [ -z ${FORCE} ]; then
        echo "cppcheck found in ${CPPCHECK_EXE}. Add --force for re-installation."
        exit 0
    fi

    # Install script prerequisite packages
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends ca-certificates curl cmake make g++
}

function install_cppcheck {
    # Create temp dir
    CPPCHECK_TEMP_DIR=$(mktemp -d -t cppcheck-temp-XXXXXX)
    trap "rm -rf $CPPCHECK_TEMP_DIR" EXIT

    set -x

    # Download cppcheck sources
    cd $CPPCHECK_TEMP_DIR
    curl -L https://github.com/danmar/cppcheck/archive/refs/tags/$CPPCHECK_GIT_TAG.tar.gz -o $CPPCHECK_GIT_TAG.tar.gz
    tar -xvf $CPPCHECK_GIT_TAG.tar.gz

    # Build and install
    mkdir build && cd build
    cmake ../cppcheck-$CPPCHECK_GIT_TAG
    make -j
    make install

    set +x
}

function main {
    parse_args $@
    prepare
    install_cppcheck
    echo "cppcheck successfully installed."
}

main $@
