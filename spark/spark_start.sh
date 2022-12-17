#!/bin/bash

set -eu

DELIM="================================================================================"

SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPTS_DIR="$(dirname $SCRIPT_NAME)"

. $SCRIPTS_DIR/set_spark_env.sh

$SPARK_HOME/sbin/start-master.sh
$SPARK_HOME/sbin/start-worker.sh spark://${HOSTNAME}:7078
$SPARK_HOME/sbin/start-history-server.sh

echo $DELIM
echo "Spark started."
echo
echo "Master:         http://localhost:8080"
echo "History server: http://localhost:18080"
echo "Executors (*):  http://localhost:4040"
echo
echo "(*) During a running application."
echo $DELIM
