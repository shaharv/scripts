#!/bin/bash

set -eu +x

function port_args() {
    EXTRA_PORTS=${EXTRA_PORTS//,/ }
    # Forward host port 55556 to port 22 (the default ssh port) in QEMU
    echo -n ",hostfwd=tcp::55556-:22"
    for PORT in ${PORTS[@]} $EXTRA_PORTS
    do
        echo -n ",hostfwd=tcp::$PORT-:$PORT"
    done
}

ARGS=$@
PORTS=(1234) # List of ports to open in QEMU
EXTRA_PORTS=${EXTRA_PORTS:-} # Comma seperated list of port numbers
QEMU_WORKDIR=${QEMU_WORKDIR:-$HOME/qemu}
QEMU_LOGS=$QEMU_WORKDIR/logs
QEMU_QCOW2_IMAGE=$QEMU_WORKDIR/images/ubuntu-desktop-20.04.qcow2
QEMU_SHARED=$QEMU_WORKDIR/shared
QEMU_PORT_ARGS=$(port_args $PORTS)

mkdir -p $QEMU_LOGS

set -x
$QEMU_WORKDIR/build/qemu-system-x86_64  \
    -machine q35 \
    -m 16G -vnc :0 -enable-kvm  -smp 4 \
    -cpu host,pdpe1gb \
    -serial file:$QEMU_LOGS/boot.log \
    -virtfs local,path=$QEMU_SHARED,mount_tag=host0,security_model=none,id=host0,multidevs=remap \
    -drive if=none,id=ubuntu_drive,file=qemu/images/$QEMU_QCOW2_IMAGE,cache=none \
    -device virtio-blk-pci,drive=ubuntu_drive,bootindex=0 \
    -device e1000,netdev=net0 \
    -netdev user,id=net0$QEMU_PORT_ARGS
