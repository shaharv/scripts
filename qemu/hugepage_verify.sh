#!/bin/bash -eu

HUGEPAGE_SIZE=$(grep Hugepagesize /proc/meminfo | sed 's/Hugepagesize:\s\+//')
EXPECTED_HUGEPAGE_SIZE="1048576 kB"

if ! [ "$HUGEPAGE_SIZE" = "$EXPECTED_HUGEPAGE_SIZE" ]; then
    echo "ERROR: Hugepage size is $HUGEPAGE_SIZE, expected $EXPECTED_HUGEPAGE_SIZE!"
    exit 1
fi

echo "Hugepage size is $HUGEPAGE_SIZE."
