#!/bin/bash

set -euo pipefail

function usage {
    echo "Usage: $0 --version <N> [options]"
    echo
    echo "Where N is the LLVM major version. For example: $0 --version 19"
    echo
    echo "Options:"
    echo "--help       Display this usage"
}

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

LLVM_VERSION=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --help) usage; exit 0;;
        --version) shift; LLVM_VERSION=$1; shift;;
        *) echo "Error: unknown argument: $1"; usage; exit 1;;
    esac
done

NUMBER_REGEX='^[0-9]+$'
if ! [[ $LLVM_VERSION =~ $NUMBER_REGEX ]]; then
    echo "Error: invalid version specified: $LLVM_VERSION."
    usage
    exit 1
fi

if [ `id -u` != 0 ] ; then
    echo "Must be run as root! Please add sudo."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
INSTALL_CMD="apt-get install -y --no-install-recommends"

# Update apt repositories
apt-get update

# Install prerequisite packages
$INSTALL_CMD lsb-release wget software-properties-common gnupg ca-certificates

# Install LLVM packages using the official install script
TEMP_LLVM_SH=$(mktemp /tmp/llvm-XXXXXX.sh)
wget https://apt.llvm.org/llvm.sh -O $TEMP_LLVM_SH
chmod +x $TEMP_LLVM_SH
$TEMP_LLVM_SH $LLVM_VERSION # all
rm $TEMP_LLVM_SH

# Install extra LLVM packages.
# The "all" parameter is broken with LLVM 19, so install extra packages manually.
$INSTALL_CMD clang-tidy-19

echo "Running update-alternatives for LLVM $LLVM_VERSION..."
SCRIPT_DIR="$(realpath $(dirname $0))"
$SCRIPT_DIR/llvm_update_alternatives.sh --llvm-version $LLVM_VERSION

echo "LLVM $LLVM_VERSION was installed successfully."
