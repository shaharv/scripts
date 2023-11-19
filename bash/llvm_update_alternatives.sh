#!/bin/bash

set -euo pipefail

LLVM_VERSION=${1:-`echo 16`}
PRIORITY=$(( $LLVM_VERSION * 100 ))

if [ `id -u` != 0 ] ; then
    echo "Must be run as root!"
    exit 1
fi

update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/lldb lldb /usr/bin/lldb-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/lld lld /usr/bin/lld-$LLVM_VERSION $PRIORITY
update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-$LLVM_VERSION $PRIORITY

# llvm-symbolizer is required for debug information in address sanitizer stack traces.
# It should be set in the environment of the sanitized program by setting:
# ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer
# See: https://stackoverflow.com/a/36757623/7256341
update-alternatives --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $PRIORITY

# Install symlink to run-clang-tidy
ln -sf $(readlink -f /usr/bin/run-clang-tidy-$LLVM_VERSION) /usr/bin/run-clang-tidy

echo "update-alternatives options for LLVM $LLVM_VERSION were successfully installed."
