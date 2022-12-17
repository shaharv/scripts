#!/bin/bash

set -eu

SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPTS_DIR="$(dirname $SCRIPT_NAME)"

. $SCRIPTS_DIR/set_spark_env.sh

$SPARK_HOME/sbin/stop-master.sh
$SPARK_HOME/sbin/stop-worker.sh spark://${HOSTNAME}:7078
$SPARK_HOME/sbin/stop-history-server.sh
