#!/bin/bash

set -eu

# --------------------------------------------------------------------------------
# Create Spark folders
# --------------------------------------------------------------------------------

# Set Spark log and work dirs
SPARK_LOG_DIR=${SPARK_LOG_DIR:-/tmp/spark-logs}
mkdir -p $SPARK_LOG_DIR

export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=$SPARK_LOG_DIR"

# --------------------------------------------------------------------------------
# Set Spark options using env. variables.
# Exported variable are read by Spark when starting the master and worker nodes.
# --------------------------------------------------------------------------------

# Set Spark master URL and ports
export SPARK_MASTER_PORT=${SPARK_MASTER_PORT:-7078}
export SPARK_DRIVER_PORT=${SPARK_DRIVER_PORT:-7079}
hostname=$(hostname)
MASTER_URL="spark://${hostname}:${SPARK_MASTER_PORT}"
export SPARK_LOCAL_HOSTNAME=${hostname}

SPARK_DIRS=${SPARK_DIRS:-/tmp/spark}
export SPARK_LOCAL_DIRS=${SPARK_DIRS}/temp
export SPARK_WORKER_DIR=${SPARK_DIRS}/worker

# Set the number of cores for the worker and driver.
# Make sure the number of worker cores is even, to prevent cache performance issues.
export SPARK_WORKER_CORES=$(nproc --all)

# export SPARK_WORKER_MEMORY for defining the physical memory limit of the worker node.
# The total max. memory used by the worker includes executors and driver memory
# (in cluster mode, the driver runs on the worker node), including heap and off-heap
# memory of each executor.
totalMemGb=$(free -g -h -t | grep Mem: | sed 's/Gi.*//g' | sed 's/Mem: \+//')
totalMemGbRounded=${totalMemGb%.*} # remove the fraction
export SPARK_WORKER_MEMORY="$totalMemGbRounded""G"

# Driver memory of 4G should be enough for most tasks. Spark default is 1G.
export SPARK_DRIVER_MEMORY=4G
