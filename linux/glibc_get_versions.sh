#!/bin/bash

set -euo pipefail

# Print the GLIBC and GLIBCXX versions.

LIBSTDCPP_LIB="/usr/lib/x86_64-linux-gnu/libstdc++.so.6"
GLIBC_VERSION=$(ldd --version | grep -i LIBC | sed 's/^.*LIBC.*) //I')
GLIBCXX_VERSION=$(strings $LIBSTDCPP_LIB | grep GLIBCXX_3 | sed s/^.*GLIBCXX/GLIBCXX/ | sort -V | tail -1)

echo "GLIBC version: ${GLIBC_VERSION}"
echo "GLIBCXX version: ${GLIBCXX_VERSION}"
echo "libstdc++.so.6 realpath: $(realpath $LIBSTDCPP_LIB)"
