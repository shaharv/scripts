#!/bin/bash -eu

SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_NAME)
source $SCRIPT_DIR/qemu_common.sh

echo "Waiting for QEMU VM to load..."

# Wait for qemu to start.
# Using busy loop is simple and effective approach to keep trying
# until the connection to qemu and the qemu operation succeed.
# Using "sshpass ssh -o ConnectTimeout=N" is not enough since
# it would fail with error if host is unreachable (exitcode 255).
connect_attempts=0
while ! timeout 10s sshpass -p $qemu_pass ssh $qemu_user -p $qemu_port "cd ."
do
  sleep 5
  let connect_attempts++ || true
  echo "Connect attempt $connect_attempts..."
  if [ $connect_attempts -eq $qemu_max_connect_attempts ]; then
    echo "Failed to connect to QEMU after $qemu_max_connect_attempts attempts."
    exit 1
  fi
done

echo "QEMU is up."
