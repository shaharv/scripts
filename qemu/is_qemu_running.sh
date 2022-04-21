#!/bin/bash -eu

set +e
QEMU_PROC=`ps aux | grep qemu-system-x86_64 | grep -v grep`
set -e

if [[ -z "$QEMU_PROC" ]]; then
  echo "No qemu processes detected."
  exit 0
else
  echo "qemu process detected!"
  echo $QEMU_PROC
  exit 1
fi
