#!/bin/bash

set -eu

# This script sets Spark global configuration options, as well as preparing common
# options to be used by Spark command line tools.
#
# There are 3 types of variables used in the script:
# 1. Spark global options. Those are variables respected by Spark. They are
#    preceeded by "export".
# 2. Script parameters which are used to set Spark options, and could be overriden
#    by the environment. These variables are named in UPPER_CASE style.
# 3. Local variables which are used for intermediate calculations. These variables
#    are named in camelCase style.

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}

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

# Set Spark log and work dirs
SPARK_LOG_DIR=${SPARK_LOG_DIR:-/tmp/spark-logs}
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=$SPARK_LOG_DIR"

# --------------------------------------------------------------------------------
# Set Spark CPU cores default values
# --------------------------------------------------------------------------------

# Set the number of cores for the worker and driver.
# Make sure the number of worker cores is even, to prevent cache performance issues.
export SPARK_WORKER_CORES=$(nproc --all)

# Set the number of cores for each executor and the driver application.
# Make sure the number of executor cores is even, to prevent cache performance issues.
# Example calculation: if SPARK_WORKER_CORES is 12, and we set 2 cores for driver and
# 2 cores for each executor, then we have 5 executors (12 = 5 x 2 + 2).
SPARK_DRIVER_CORES=${SPARK_DRIVER_CORES:-2}
SPARK_EXECUTOR_CORES=${SPARK_EXECUTOR_CORES:-$(bc <<< $SPARK_WORKER_CORES/8)}
let SPARK_TOTAL_EXECUTOR_CORES=($SPARK_WORKER_CORES-$SPARK_DRIVER_CORES)
SPARK_EXECUTOR_INSTANCES=${SPARK_EXECUTOR_INSTANCES:-$(bc <<< $SPARK_TOTAL_EXECUTOR_CORES/$SPARK_EXECUTOR_CORES)}

# Set spark.max.cores identical to SPARK_WORKER_CORES, meaning that a single
# application will be served with all cores.
SPARK_CORES_MAX=${SPARK_CORES_MAX:-$SPARK_WORKER_CORES}

# Spark shuffle partitions minimum is typically twice the number of cores.
SPARK_SHUFFLE_PARTITIONS=${SPARK_SHUFFLE_PARTITIONS:-$(bc <<< $SPARK_CORES_MAX*2)}

# --------------------------------------------------------------------------------
# Set Spark memory options default values
# --------------------------------------------------------------------------------

# export SPARK_WORKER_MEMORY for defining the physical memory limit of the worker node.
# The total max. memory used by the worker includes executors and driver memory
# (in cluster mode, the driver runs on the worker node), including heap and off-heap
# memory of each executor.
totalMemGb=$(free -g -h -t | grep Mem: | sed 's/Gi.*//g' | sed 's/Mem: \+//')
totalMemGbRounded=${totalMemGb%.*} # remove the fraction
export SPARK_WORKER_MEMORY="$totalMemGbRounded""G"

# Driver memory of 4G should be enough for most tasks. Spark default is 1G.
SPARK_DRIVER_MEMORY_GB=${SPARK_DRIVER_MEMORY_GB:-4}
export SPARK_DRIVER_MEMORY="${SPARK_DRIVER_MEMORY_GB}G"

# Set the same amount of memory per executor core.
SPARK_WORKER_MEMORY_GB=${SPARK_WORKER_MEMORY_GB:-${SPARK_WORKER_MEMORY//G}}
SPARK_EXECUTOR_MEMORY_GB=${SPARK_EXECUTOR_MEMORY_GB:-$(echo "scale=0; x=($SPARK_WORKER_MEMORY_GB-$SPARK_DRIVER_MEMORY_GB)/$SPARK_EXECUTOR_INSTANCES; if(x<1) print 1 else x" | bc)}
SPARK_EXECUTOR_MEMORY_OVERHEAD_GB=${SPARK_EXECUTOR_MEMORY_OVERHEAD_GB:-1}

# --------------------------------------------------------------------------------
# Set Spark options for command line applications
# --------------------------------------------------------------------------------

SPARK_METASTORE_OPTIONS=${SPARK_METASTORE_OPTIONS:-" \
    --conf spark.hadoop.javax.jdo.option.ConnectionURL=jdbc:derby:${SPARK_DIRS}/metastore_db;create=true \
    --conf spark.sql.hive.metastorePartitionPruning=true"}

GLUTEN_JAR=${GLUTEN_JAR:-gluten-velox-bundle-spark3.5_2.12-centos_7_x86_64-1.3.0.jar}

GLUTEN_OPTIONS=${GLUTEN_OPTIONS:-" \
    --conf spark.plugins=org.apache.gluten.GlutenPlugin \
    --conf spark.gluten.sql.debug=true \
    --conf spark.memory.offHeap.enabled=true \
    --conf spark.memory.offHeap.size="${SPARK_EXECUTOR_MEMORY_GB}G" \
    --conf spark.shuffle.manager=org.apache.spark.shuffle.sort.ColumnarShuffleManager \
    --jars $SPARK_HOME/jars/$GLUTEN_JAR"}

SPARK_DRIVER_OPTIONS=${SPARK_DRIVER_OPTIONS:-" \
    --conf spark.driver.cores=${SPARK_DRIVER_CORES} \
    --conf spark.driver.extraJavaOptions="-Dio.netty.tryReflectionSetAccessible=true" \
    --conf spark.driver.log.dfsDir=${SPARK_LOG_DIR} \
    --conf spark.driver.log.persistToDfs.enabled=true \
    --conf spark.driver.memory="${SPARK_DRIVER_MEMORY_GB}G" \
    --conf spark.driver.port=${SPARK_DRIVER_PORT} \
    --conf spark.driverEnv.LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"}

SPARK_EXECUTOR_OPTIONS=${SPARK_EXECUTOR_OPTIONS:-" \
    --conf spark.executor.cores=${SPARK_EXECUTOR_CORES} \
    --conf spark.executor.extraJavaOptions="-Dio.netty.tryReflectionSetAccessible=true" \
    --conf spark.executor.instances=${SPARK_EXECUTOR_INSTANCES} \
    --conf spark.executor.memory="${SPARK_EXECUTOR_MEMORY_GB}G" \
    --conf spark.executor.memoryOverhead="${SPARK_EXECUTOR_MEMORY_OVERHEAD_GB}G" \
    --conf spark.executorEnv.LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"}

SPARK_OPTIONS=${SPARK_OPTIONS:-" \
    --conf spark.cores.max=${SPARK_CORES_MAX} \
    --conf spark.deploy.mode=client \
    --conf spark.eventLog.dir=${SPARK_LOG_DIR} \
    --conf spark.eventLog.enabled=true \
    --conf spark.history.fs.logDirectory=${SPARK_LOG_DIR} \
    --conf spark.sql.catalogImplementation=hive \
    --conf spark.sql.shuffle.partitions=${SPARK_SHUFFLE_PARTITIONS} \
    --conf spark.sql.sources.parallelPartitionDiscovery.threshold=${SPARK_WORKER_CORES} \
    --conf spark.sql.sources.parallelPartitionDiscovery.parallelism=${SPARK_WORKER_CORES} \
    --conf spark.sql.warehouse.dir=${SPARK_DIRS}/spark-warehouse"}

# --------------------------------------------------------------------------------
# Print Spark cores and memory default values
# --------------------------------------------------------------------------------

echo "Spark default values set:" >&2
echo >&2
echo "Spark worker memory (GB):   $SPARK_WORKER_MEMORY_GB" >&2
echo "Spark worker cores:         $SPARK_WORKER_CORES" >&2
echo "Spark driver memory (GB):   $SPARK_DRIVER_MEMORY_GB" >&2
echo "Spark driver cores:         $SPARK_DRIVER_CORES" >&2
echo "Spark executors:            $SPARK_EXECUTOR_INSTANCES" >&2
echo "Spark executor memory (GB): $SPARK_EXECUTOR_MEMORY_GB" >&2
echo "Spark executor cores:       $SPARK_EXECUTOR_CORES" >&2
echo >&2
