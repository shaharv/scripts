#!/bin/bash

set -eu

# Set Spark variables
SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR="$(dirname $SCRIPT_NAME)"
. $SCRIPT_DIR/set_spark_env.sh

# Set the number of cores for each executor and the driver application.
# Make sure the number of executor cores is even, to prevent cache performance issues.
# Example calculation: if SPARK_WORKER_CORES is 12, and we set 2 cores for driver and
# 2 cores for each executor, then we have 5 executors (12 = 5 x 2 + 2).
SPARK_DRIVER_CORES=2
SPARK_EXECUTOR_CORES=2
let SPARK_TOTAL_EXECUTOR_CORES=($SPARK_WORKER_CORES-$SPARK_DRIVER_CORES)
SPARK_EXECUTOR_INSTANCES=$(bc <<< $SPARK_TOTAL_EXECUTOR_CORES/$SPARK_EXECUTOR_CORES)

# Set spark.max.cores identical to SPARK_WORKER_CORES, meaning that a single
# application will be served with all cores.
SPARK_CORES_MAX=$SPARK_WORKER_CORES

# Set the same amount of memory per executor core.
SPARK_DRIVER_MEMORY=1G
SPARK_DRIVER_MEMORY_GB=${SPARK_DRIVER_MEMORY//G}
SPARK_WORKER_MEMORY_GB=${SPARK_WORKER_MEMORY//G}
SPARK_EXECUTOR_MEMORY_GB=$(echo "scale=1; x=($SPARK_WORKER_MEMORY_GB-$SPARK_DRIVER_MEMORY_GB)/$SPARK_EXECUTOR_INSTANCES; if(x<1 && x>0) print 0; x" | bc)
SPARK_EXECUTOR_MEMORY=${SPARK_EXECUTOR_MEMORY_GB%.*}"G" # remove the fraction

echo "Starting spark-shell..."
echo
echo "Spark worker memory:   $SPARK_WORKER_MEMORY"
echo "Spark worker cores:    $SPARK_WORKER_CORES"
echo "Spark driver memory:   $SPARK_DRIVER_MEMORY"
echo "Spark driver cores:    $SPARK_DRIVER_CORES"
echo "Spark executors:       $SPARK_EXECUTOR_INSTANCES"
echo "Spark executor memory: $SPARK_EXECUTOR_MEMORY"
echo "Spark executor cores:  $SPARK_EXECUTOR_CORES"
echo

set -x

${SPARK_HOME}/bin/spark-shell \
    --master "${MASTER_URL}" \
    ${SPARK_SHELL_ARGS[@]} \
    --conf spark.cores.max=${SPARK_CORES_MAX} \
    --conf spark.deploy.mode=client \
    --conf spark.driver.cores=${SPARK_DRIVER_CORES} \
    --conf spark.driver.log.dfsDir=${SPARK_LOG_DIR} \
    --conf spark.driver.log.persistToDfs.enabled=true \
    --conf spark.driver.memory="${SPARK_DRIVER_MEMORY}" \
    --conf spark.driver.port=${SPARK_DRIVER_PORT} \
    --conf spark.eventLog.dir=${SPARK_LOG_DIR} \
    --conf spark.eventLog.enabled=true \
    --conf spark.executor.cores=${SPARK_EXECUTOR_CORES} \
    --conf spark.executor.memory=${SPARK_EXECUTOR_MEMORY} \
    --conf spark.history.fs.logDirectory=${SPARK_LOG_DIR} \
    $@
