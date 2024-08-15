#!/bin/bash

set -euo pipefail

GLIBC_EXPECTED=""
GLIBCXX_EXPECTED=""

function usage {
    echo "Usage: $0 [--glibc-expected=<ver>][--glibcxx-expected=<ver>][--help]"
    echo
    echo "Print or verify the installed versions of GLIBC and GLIBCXX."
}

function parse_args {
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --glibc-expected=*) GLIBC_EXPECTED=${OPT/--glibc-expected=/}; shift;;
            --glibcxx-expected=*) GLIBCXX_EXPECTED=${OPT/--glibcxx-expected=/}; shift;;
            --help) usage; exit 0;;
            *) echo "Error: unknown argument: $1"; usage; exit 1;;
        esac
    done
}

function detect_glibc_versions {
    # Get the location of libstdc++.so.6. Possible locations:
    #
    # /lib/x86_64-linux-gnu/libstdc++.so.6 (Ubuntu, Debian)
    # /lib64/libstdc++.so.6 (CentOS, AlmaLinux)
    LIBSTDCPP_LIB="$(ldconfig -p | grep libstdc++.so.6 | grep x86-64 | sed 's/^.*=> //')"
    if [ ! -e "$LIBSTDCPP_LIB" ]; then
        echo "Error: libstdc++.so.6 could not be detected."
        exit 1
    fi

    # Detect the GLIBC and GLIBCXX versions and print them
    GLIBC_VERSION=$(getconf GNU_LIBC_VERSION | sed 's/glibc //')
    GLIBCXX_VERSION=$(strings $LIBSTDCPP_LIB | grep GLIBCXX_3 | sed s/^.*GLIBCXX_// | sort -V | tail -1)

    echo "GLIBC version: ${GLIBC_VERSION}"
    echo "GLIBCXX version: ${GLIBCXX_VERSION}"
    echo "libstdc++.so.6 realpath: $(realpath $LIBSTDCPP_LIB)"
}

# Compare two version strings, typically in the format X.Y.Z (e.g. 1.2.3).
# The comparison is done for each numberic component, starting from the leftmost one.
# While GLIBC version is typically represented as a float number (such as 2.25), GLIBCXX versions
# might have multiple dots (e.g. 3.4.22).
function compare_versions() {
    local VERSION_A=$1
    local VERSION_B=$2

    # Split the version strings into arrays with their numberic components, using dot as the seperator
    IFS='.' read -ra VER_A <<< "$VERSION_A"
    IFS='.' read -ra VER_B <<< "$VERSION_B"

    # Iterate the numeric components and compare them one after the other as decimals
    for ((i=0; i<${#VER_A[@]} || i<${#VER_B[@]}; i++)); do
        local a=${VER_A[i]:-0}
        local b=${VER_B[i]:-0}
        if ((10#$a > 10#$b)); then
            echo -1
            return
        elif ((10#$a < 10#$b)); then
            echo 1
            return
        fi
    done
}

function verify_version {
    COMPONENT=$1
    EXPECTED_VERSION=$2
    ACTUAL_VERSION=$3
    VERSION_COMPARE_RESULT=$(compare_versions "$ACTUAL_VERSION" "$EXPECTED_VERSION")
    if [[ $VERSION_COMPARE_RESULT -lt 0 ]]; then
        echo "ERROR: $COMPONENT version is newer than expected! Expected $EXPECTED_VERSION, found $ACTUAL_VERSION."
        exit 1
    else
        echo "OK: $COMPONENT version is $ACTUAL_VERSION, which is older or equal to $EXPECTED_VERSION."
    fi
}

function main {
    parse_args $@

    detect_glibc_versions

    if [ "$GLIBC_EXPECTED" != "" ]; then
        echo "Verifying GLIBC version..."
        verify_version "GLIBC" "$GLIBC_EXPECTED" "$GLIBC_VERSION"
    fi
    if [ "$GLIBCXX_EXPECTED" != "" ]; then
        echo "Verifying GLIBCXX version..."
        verify_version "GLIBCXX" "$GLIBCXX_EXPECTED" "$GLIBCXX_VERSION"
    fi
}

main $@
