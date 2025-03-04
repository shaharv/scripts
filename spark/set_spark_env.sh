#!/bin/bash

set -eu

# Set Spark options using env. variables.
# Exported variable are respected by Spark when starting Spark master and worker nodes.
# Local variables are for setting script options.

# Set Spark master URL and ports
export SPARK_MASTER_PORT=7078
export SPARK_DRIVER_PORT=7079
HOSTNAME=$(hostname)
MASTER_URL="spark://${HOSTNAME}:${SPARK_MASTER_PORT}"
export SPARK_LOCAL_HOSTNAME=${HOSTNAME}

# Set Spark log and work dirs
SPARK_LOG_DIR=/tmp/spark-logs
mkdir -p $SPARK_LOG_DIR
export SPARK_LOCAL_DIRS=/tmp/spark-temp
export SPARK_WORKER_DIR=/tmp/spark-worker
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=$SPARK_LOG_DIR"

# Set the number of cores for the worker and driver.
# Make sure the number of worker cores is even, to prevent cache performance issues.
export SPARK_WORKER_CORES=$(nproc --all)

# export SPARK_WORKER_MEMORY for defining memory limits for the worker node.
# The total max. memory used by the worker includes executors and driver
# memory (in cluster mode), including heap and off-heap memory of each executor.
TOTAL_MEM_GB=$(free -g -h -t  | grep Mem: | sed 's/Gi.*//g' | sed 's/Mem: \+//')
TOTAL_MEM_GB_ROUNDED=${TOTAL_MEM_GB%.*} # remove the fraction
export SPARK_WORKER_MEMORY="$TOTAL_MEM_GB_ROUNDED""G"

# Driver memory of 4G should be enough for most tasks. Spark default is 1G.
export SPARK_DRIVER_MEMORY=4G
