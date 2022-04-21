#!/bin/bash -eu

# Kill QEMU gracefully
function kill_qemu {
    set +e
    sshpass -p $qemu_pass ssh $qemu_user -p $qemu_port "sudo shutdown now"
    sleep 30
    pkill -9 qemu-system-x86_64 | true
    echo "Gracefully killed QEMU"
    set -e
}

# Start QEMU in the background
function start_qemu {
    echo "Starting QEMU"
    QEMU_DIR=$1
    shift
    $QEMU_DIR/qemu-system-x86_64 $@ &
    pid=$!
    echo "QEMU started with pid=$pid"
}

# Wait for QEMU to start
function wait_for_qemu {
    echo "Waiting for VM to load..."
    set +x
    # Using a busy loop is a simple approach to keep trying until
    # the connection to qemu and the qemu operation succeed.
    # Using "sshpass ssh -o ConnectTimeout=N" is not enough since
    # it would fail with error if host is unreachable (exitcode 255).
    while ! sshpass -p $qemu_pass ssh $qemu_user -p $qemu_port "true"
    do
        printf "%c" "."
        sleep 1
    done
    set -x
}
