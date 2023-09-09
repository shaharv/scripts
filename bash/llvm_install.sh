#!/bin/bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <llvm major version>"
    exit 1
fi

LLVM_VERSION=$1
NUMBER_REGEX='^[0-9]+$'
if ! [[ $LLVM_VERSION =~ $NUMBER_REGEX ]]; then
    echo "Error: invalid version specified: $LLVM_VERSION."
    exit 1
fi

PRIORITY=$(( $LLVM_VERSION * 100 ))
DISTRO=$(lsb_release -c -s)

if [ `id -u` != 0 ] ; then
    echo "Must be run as root!"
    exit 1
fi

# Set up LLVM apt repository
apt install -y --no-install-recommends software-properties-common wget gnupg
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add -
add-apt-repository "deb http://apt.llvm.org/$DISTRO/ llvm-toolchain-$DISTRO-$LLVM_VERSION main" && apt update

# Install LLVM tools
apt install -y \
    clang-$LLVM_VERSION \
    clang-format-$LLVM_VERSION \
    clang-tidy-$LLVM_VERSION \
    lld-$LLVM_VERSION \
    lldb-$LLVM_VERSION \
    libc++-$LLVM_VERSION-dev \
    libc++abi-$LLVM_VERSION-dev

# Update alternatives
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
