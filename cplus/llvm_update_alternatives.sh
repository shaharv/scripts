#!/bin/bash

# Set LLVM tools default versions using update-alternatives.

set -euo pipefail

function usage {
    echo "Usage: $0 --llvm-version <N>"
    echo
    echo "Where N is the LLVM major version. For example: $0 --llvm-version 19"
    echo
    echo "Options:"
    echo "--llvm-version <N> Set the LLVM version to be made default"
    echo "--help             Display this usage"
}

if [[ $# -eq 0 ]]; then
    usage
    exit 0
fi

LLVM_VERSION=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --help) usage; exit 0;;
        --llvm-version) shift; LLVM_VERSION=$1; shift;;
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
    echo "Must be run as root!"
    exit 1
fi

PRIORITY=$(( $LLVM_VERSION * 100 ))

update-alternatives --force --install /usr/bin/clang clang /usr/bin/clang-$LLVM_VERSION $PRIORITY
update-alternatives --force --install /usr/bin/clang-format clang-format /usr/bin/clang-format-$LLVM_VERSION $PRIORITY
update-alternatives --force --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-$LLVM_VERSION $PRIORITY
update-alternatives --force --install /usr/bin/lldb lldb /usr/bin/lldb-$LLVM_VERSION $PRIORITY
update-alternatives --force --install /usr/bin/lld lld /usr/bin/lld-$LLVM_VERSION $PRIORITY
update-alternatives --force --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-$LLVM_VERSION $PRIORITY

# llvm-symbolizer is required for debug information in address sanitizer stack traces.
# It should be set in the environment of the sanitized program by setting:
# ASAN_SYMBOLIZER_PATH=/usr/bin/llvm-symbolizer
# See: https://stackoverflow.com/a/36757623/7256341
update-alternatives --force --install /usr/bin/llvm-symbolizer llvm-symbolizer /usr/bin/llvm-symbolizer-$LLVM_VERSION $PRIORITY

# Install symlink to run-clang-tidy
ln -sf $(readlink -f /usr/bin/run-clang-tidy-$LLVM_VERSION) /usr/bin/run-clang-tidy

echo "update-alternatives options for LLVM $LLVM_VERSION were successfully installed."
