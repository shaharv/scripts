#!/bin/bash -eu

SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_NAME)
QEMU_DIR=$SCRIPT_DIR
QEMU_ARGS=""
WAIT_FOR_QEMU="0"
CONNECT_ATTEMPTS=1

source $SCRIPT_DIR/qemu_common.sh

function check_args {
  while [[ $# -gt 0 ]]; do
    OPT=$1
    if [[ $OPT == "--qemu-dir="* ]]; then
      QEMU_DIR=${OPT/--qemu-dir=/}
      echo "Using qemu in $QEMU_DIR"
    elif [[ $OPT == "--wait" ]]; then
      WAIT_FOR_QEMU="1"
    else
      QEMU_ARGS+="$1 "
    fi
  shift
  done
}

function start_qemu_once {
  echo "Starting QEMU"
  $QEMU_DIR/start_qemu_with_image.sh $@ &
  timeout 10s bash -c 'until [[ ! -z $(pgrep qemu-system-x86) ]]; do sleep 1; done'
  pid=$(pgrep qemu-system-x86)
  echo "QEMU started with pid=$pid"
}

if ! $SCRIPT_DIR/is_qemu_running.sh; then
  echo "Cannot start QEMU."
  exit 1
fi

check_args $@
start_qemu_once $QEMU_ARGS

if [[ "$WAIT_FOR_QEMU" == "1" ]]; then
  while [ $CONNECT_ATTEMPTS -le $qemu_max_start_attempts ]; do
    if ! $SCRIPT_DIR/wait_for_qemu.sh; then
      echo "============================================================"
      echo "QEMU is unresponsive. Trying to restart (after #$CONNECT_ATTEMPTS attempt)"
      echo "============================================================"
      let CONNECT_ATTEMPTS++ || true
      $SCRIPT_DIR/kill_qemu.sh
      start_qemu_once $QEMU_ARGS
    else
      echo "QEMU has started. Godspeed!"
      exit 0
    fi
  done
fi

echo "============================================================"
echo "QEMU failed to start. Consider rebooting the host machine."
echo "============================================================"
exit 1
