#!/bin/bash

set -euo pipefail

# Verify the GLIBC version of the provided shared object is the required minimum.
# The GLIBC version determines the level of compatibility to different Linux distributions.
# Usage: glibc_verify <path-to-so> <GLIBC min version>.
# For example: glibc_verify /usr/lib/libmultipath.so 2.28
function glibc_verify {
    SO_PATH=$1
    GLIBC_VERSION_EXPECTED=$2
    GLIBC_VERSION=$(strings $SO_PATH | grep GLIBC_ | sed s/.*@// | sort -V | tail -n 1 | sed s/GLIBC_//)
    GLIBC_IS_AS_EXPECTED=$(echo "$GLIBC_VERSION <= $GLIBC_VERSION_EXPECTED" | bc)
    if [ $GLIBC_IS_AS_EXPECTED -eq 0 ]; then
        echo "GLIBC version of $SO_PATH is newer than expected! Expected $GLIBC_VERSION_EXPECTED, found $GLIBC_VERSION."
        return 1
    else
        echo "GLIBC version of $SO_PATH is $GLIBC_VERSION, which is older or equal to $GLIBC_VERSION_EXPECTED."
    fi
    return 0
}

function usage {
    echo "Usage: $0 <path to .so> <GLIBC minimum version>"
    echo
    echo "This script will return non-zero status if the GLIBC minimum version"
    echo "requirement is not met for the given .so, zero status otherwise."
    echo
    echo "For example, './glibc_verify.sh /usr/lib/libBLT.so 2.28' will return"
    echo "true when libBLT.so GLIBC requirement is GLIBC 2.28 or older."
}

if [ "${1:-}" == "" ]; then
    echo "Please provide .so path as the first argument."
    echo
    usage
    exit 0
fi

if [ "${2:-}" == "" ]; then
    echo "Please provide GLIBC minimum version requirement as the second argument. For example, 2.28."
    echo
    usage
    exit 0
fi

SO_PATH=$1
GLIBC_VERSION=$2

if ! [ -f $1 ]; then
    echo "Error: $SO_PATH does not exist."
    exit 1
fi

glibc_verify $SO_PATH $GLIBC_VERSION
