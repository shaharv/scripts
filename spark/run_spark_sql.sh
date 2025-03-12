#!/bin/bash

set -euo pipefail

# Set Spark variables
SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR="$(dirname $SCRIPT_NAME)"
. $SCRIPT_DIR/set_spark_env.sh

set -x

${SPARK_HOME}/bin/spark-sql \
    --master "${MASTER_URL}" \
    ${SPARK_SHELL_ARGS[@]} \
    ${GLUTEN_OPTIONS} \
    ${SPARK_DRIVER_OPTIONS} \
    ${SPARK_EXECUTOR_OPTIONS} \
    ${SPARK_METASTORE_OPTIONS} \
    ${SPARK_OPTIONS} \
    ${SPARK_EXTRA_OPTIONS:-} \
    --database ${DB_NAME} \
    -f $@
