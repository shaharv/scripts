#!/bin/bash

set -euo pipefail

# Set Spark variables
SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR="$(dirname $SCRIPT_NAME)"
. $SCRIPT_DIR/set_spark_env.sh

echo "Starting spark-shell..."
echo
echo "Spark worker memory (GB):   $SPARK_WORKER_MEMORY_GB"
echo "Spark worker cores:         $SPARK_WORKER_CORES"
echo "Spark driver memory (GB):   $SPARK_DRIVER_MEMORY_GB"
echo "Spark driver cores:         $SPARK_DRIVER_CORES"
echo "Spark executors:            $SPARK_EXECUTOR_INSTANCES"
echo "Spark executor memory (GB): $SPARK_EXECUTOR_MEMORY_GB"
echo "Spark executor cores:       $SPARK_EXECUTOR_CORES"
echo

set -x

${SPARK_HOME}/bin/spark-shell \
    --master "${MASTER_URL}" \
    ${SPARK_SHELL_ARGS[@]} \
    ${GLUTEN_OPTIONS} \
    ${SPARK_DRIVER_OPTIONS} \
    ${SPARK_EXECUTOR_OPTIONS} \
    ${SPARK_METASTORE_OPTIONS} \
    ${SPARK_OPTIONS} \
    ${SPARK_EXTRA_OPTIONS:-} \
    $@
