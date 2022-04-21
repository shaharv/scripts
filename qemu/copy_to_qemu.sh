#!/bin/bash -eu

set -o pipefail

SCRIPT_NAME=`readlink -f ${BASH_SOURCE[0]}`
SCRIPT_DIR=`echo $SCRIPT_NAME | xargs dirname`
SRC_FILES=""
QEMU_DST=""
QEMU_DIR="$SCRIPT_DIR/../.."
REMOVE_DST_FOLDER=""
NOKILL=""

source $SCRIPT_DIR/qemu_common.sh

function check_args {
  if [[ $# -lt 2 ]]; then
    echo "Usage: $SCRIPT_NAME [--qemu-dir=<qemu path>] <files to copy> <qemu destination folder>"
    exit 1
  fi
  while [[ $# -gt 1 ]]; do
    OPT=$1
    if [[ $OPT == "--qemu-dir="* ]]; then
      QEMU_DIR=${OPT/--qemu-dir=/}
      echo "Using qemu in $QEMU_DIR"
    elif [ $OPT = "--remove-dest-folder" ]; then
      REMOVE_DST_FOLDER="1"
    elif [ $OPT = "--nokill" ]; then
      NOKILL="1"
    else
      SRC_FILES+="$1 "
    fi
    shift
  done
  QEMU_DST=$1
  echo "qemu destination folder: $QEMU_DST"
}

function prep_dest_dir {
  set -x
  if [ "$REMOVE_DST_FOLDER" = "1" ]; then
    sshpass -p $qemu_pass ssh $qemu_user -p $qemu_port "rm -rf $QEMU_DST"
  fi
  sshpass -p $qemu_pass ssh $qemu_user -p $qemu_port "mkdir -p $QEMU_DST"
  set +x
}

function copy_to_qemu {
  set -x
  sshpass -p $qemu_pass scp -r -P $qemu_port $SRC_FILES $qemu_user:$QEMU_DST
  set +x
}

check_args $@
start_qemu $QEMU_DIR
wait_for_qemu
prep_dest_dir
copy_to_qemu
if [ "$NOKILL" = "" ]; then
  kill_qemu
fi
echo "Artifacts copied to qemu."
