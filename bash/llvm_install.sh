#!/bin/bash

set -euo pipefail

function usage {
    echo "Usage: $0 --version <N> [options]"
    echo
    echo "Where N is the LLVM major version. For example: $0 --version=16"
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
    echo "Must be run as sudo!"
    exit 1
fi

echo "Installing LLVM version $LLVM_VERSION."

# Install prerequisite packages
apt-get update
apt-get install -y --no-install-recommends software-properties-common wget gnupg

# Set up LLVM apt repository
DISTRO=$(lsb_release -c -s)
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
add-apt-repository "deb http://apt.llvm.org/$DISTRO/ llvm-toolchain-$DISTRO-$LLVM_VERSION main"
apt-get update

# Install LLVM tools
apt-get install -y \
    clang-$LLVM_VERSION \
    clang-format-$LLVM_VERSION \
    clang-tidy-$LLVM_VERSION \
    lld-$LLVM_VERSION \
    lldb-$LLVM_VERSION \
    libc++-$LLVM_VERSION-dev \
    libc++abi-$LLVM_VERSION-dev

PRIORITY=$(( $LLVM_VERSION * 100 ))
update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/lld lld /usr/bin/lld-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $PRIORITY

# llvm-symbolizer is required for debug information in address sanitizer stack traces.
# It should be set in the environment of the sanitized program by setting:
# ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer
# See: https://stackoverflow.com/a/36757623/7256341

echo "All done."