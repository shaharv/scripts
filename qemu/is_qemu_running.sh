#!/bin/bash -e

QEMU_PROC=$(ps aux | grep qemu-system-x86_64 | grep -v grep) || true

if [[ -z "$QEMU_PROC" ]]; then
  echo "No qemu processes detected."
  exit 0
else
  echo "qemu is already running!"
  echo $QEMU_PROC
  exit 1
fi
