#!/bin/bash -eu

SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR=$(dirname $SCRIPT_NAME)
SRC_FILES=""
QEMU_DST=""
QEMU_DIR="$SCRIPT_DIR/../.."
REMOVE_DST_FOLDER=""
NOKILL="0"

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
    $SCRIPT_DIR/run_on_qemu.sh "rm -rf $QEMU_DST"
  fi
  $SCRIPT_DIR/run_on_qemu.sh "mkdir -p $QEMU_DST"
  set +x
}

function copy_to_qemu {
  set -x
  sshpass -p $qemu_pass scp -r -P $qemu_port $SRC_FILES $qemu_user:$QEMU_DST
  set +x
}

check_args $@
$SCRIPT_DIR/start_qemu.sh --qemu-dir=$QEMU_DIR --wait
prep_dest_dir
copy_to_qemu
if [ "$NOKILL" = "0" ]; then
  $SCRIPT_DIR/kill_qemu.sh
fi
echo "Artifacts copied to qemu."
