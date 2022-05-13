#!/bin/bash -eu

SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_NAME)

source $SCRIPT_DIR/qemu_common.sh

echo "Killing QEMU."
echo "Ask the QEMU Linux to shutdown..."
sshpass -p $qemu_pass ssh $qemu_user -p $qemu_port "sudo shutdown now" || true

echo "Wait for the QEMU process to finish..."
timeout 60s bash -c 'until [[ -z $(pgrep qemu-system-x86) ]]; do sleep 1; done' || true

echo "Force kill any remaining QEMU process."
pkill -9 qemu-system-x86_64 || true

echo "Kill any process listening on port $qemu_dbg_port."
kill -9 $(lsof -t -i:$qemu_dbg_port) > /dev/null 2<&1 || true

echo "Wait for port $qemu_dbg_port to be freed..."
until [[ -z $(lsof -i:$qemu_dbg_port) ]]; do sleep 1; done

echo "Kill any process listening on port $qemu_port."
kill -9 $(lsof -t -i:$qemu_port) > /dev/null 2<&1 || true

echo "Wait for port $qemu_port to be freed..."
until [[ -z $(lsof -i:$qemu_port) ]]; do sleep 1; done

echo "QEMU is killed."
