#!/bin/bash -eu

# Import common defs
SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_NAME)
source $SCRIPT_DIR/qemu_common.sh

COMMAND=""
TIMEOUT_SEC=$qemu_sshpass_timeout_sec

function check_args {
  if [[ $# -lt 1 ]]; then
    echo "Usage: $SCRIPT_NAME [--timeout-sec=<seconds>] <command to run in qemu>"
    exit 1
  fi
  # First parameter is --timeout-sec (optional)
  if [[ $1 == "--timeout-sec="* ]]; then
    TIMEOUT_SEC=${1/--timeout-sec=/}
    shift
  fi
  COMMAND="$@"
  # Remove whitespace and check if command is empty
  if [[ -z "${COMMAND// }" ]]; then
    echo "Please specify command to run in qemu."
    exit 1
  fi
}

function run_on_qemu {
  set -x
  timeout "$TIMEOUT_SEC"s $qemu_ssh_command $COMMAND
  set +x
}

check_args $@
run_on_qemu
