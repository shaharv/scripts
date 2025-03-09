#!/bin/bash

set -euo pipefail

# Set Spark variables
SCRIPT_NAME=$(readlink -f $0)
SCRIPT_DIR="$(dirname $SCRIPT_NAME)"
. $SCRIPT_DIR/set_spark_env.sh

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-}

# Set the number of cores for each executor and the driver application.
# Make sure the number of executor cores is even, to prevent cache performance issues.
# Example calculation: if SPARK_WORKER_CORES is 12, and we set 2 cores for driver and
# 2 cores for each executor, then we have 5 executors (12 = 5 x 2 + 2).
SPARK_DRIVER_CORES=${SPARK_DRIVER_CORES:-2}
SPARK_EXECUTOR_CORES=${SPARK_EXECUTOR_CORES:-2}
let SPARK_TOTAL_EXECUTOR_CORES=($SPARK_WORKER_CORES-$SPARK_DRIVER_CORES)
SPARK_EXECUTOR_INSTANCES=${SPARK_EXECUTOR_INSTANCES:-$(bc <<< $SPARK_TOTAL_EXECUTOR_CORES/$SPARK_EXECUTOR_CORES)}

# Set spark.max.cores identical to SPARK_WORKER_CORES, meaning that a single
# application will be served with all cores.
SPARK_CORES_MAX=$SPARK_WORKER_CORES

# Set the same amount of memory per executor core.
SPARK_DRIVER_MEMORY_GB=${SPARK_DRIVER_MEMORY_GB:-1}
SPARK_WORKER_MEMORY_GB=${SPARK_WORKER_MEMORY//G}
SPARK_EXECUTOR_MEMORY_GB=${SPARK_EXECUTOR_MEMORY_GB:-$(echo "scale=0; x=($SPARK_WORKER_MEMORY_GB-$SPARK_DRIVER_MEMORY_GB)/$SPARK_EXECUTOR_INSTANCES; if(x<1 && x>0) print 0; x" | bc)}
SPARK_EXECUTOR_MEMORY_OVERHEAD_GB=${SPARK_EXECUTOR_MEMORY_OVERHEAD_GB:-1}

# Set the location of Spark metastore_db and spark-warehouse folders
SPARK_DIRS=${SPARK_DIRS:-/tmp}

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

GLUTEN_JAR=${GLUTEN_JAR:-gluten-velox-bundle-spark3.5_2.12-centos_7_x86_64-1.3.0.jar}

GLUTEN_OPTIONS=" \
    --conf spark.plugins=org.apache.gluten.GlutenPlugin \
    --conf spark.gluten.sql.debug=true \
    --conf spark.memory.offHeap.enabled=true \
    --conf spark.memory.offHeap.size="${SPARK_EXECUTOR_MEMORY_GB}G" \
    --conf spark.shuffle.manager=org.apache.spark.shuffle.sort.ColumnarShuffleManager \
    --jars $SPARK_HOME/jars/$GLUTEN_JAR"

if [ "${DISABLE_GLUTEN:-}" = "1" ]; then
    GLUTEN_OPTIONS=""
fi

set -x

${SPARK_HOME}/bin/spark-shell \
    --master "${MASTER_URL}" \
    ${SPARK_SHELL_ARGS[@]} \
    --conf spark.cores.max=${SPARK_CORES_MAX} \
    --conf spark.deploy.mode=client \
    --conf spark.driver.cores=${SPARK_DRIVER_CORES} \
    --conf spark.driver.extraJavaOptions="-Dio.netty.tryReflectionSetAccessible=true" \
    --conf spark.driver.log.dfsDir=${SPARK_LOG_DIR} \
    --conf spark.driver.log.persistToDfs.enabled=true \
    --conf spark.driver.memory="${SPARK_DRIVER_MEMORY_GB}G" \
    --conf spark.driver.port=${SPARK_DRIVER_PORT} \
    --conf spark.driverEnv.LD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
    --conf spark.eventLog.dir=${SPARK_LOG_DIR} \
    --conf spark.eventLog.enabled=true \
    --conf spark.executor.cores=${SPARK_EXECUTOR_CORES} \
    --conf spark.executor.extraJavaOptions="-Dio.netty.tryReflectionSetAccessible=true" \
    --conf spark.executor.instances=${SPARK_EXECUTOR_INSTANCES} \
    --conf spark.executor.memory="${SPARK_EXECUTOR_MEMORY_GB}G" \
    --conf spark.executor.memoryOverhead="${SPARK_EXECUTOR_MEMORY_OVERHEAD_GB}G" \
    --conf spark.executorEnv.LD_LIBRARY_PATH=${LD_LIBRARY_PATH} \
    --conf spark.hadoop.javax.jdo.option.ConnectionURL="jdbc:derby:${SPARK_DIRS}/metastore_db;create=true" \
    --conf spark.history.fs.logDirectory=${SPARK_LOG_DIR} \
    --conf spark.sql.catalogImplementation=hive \
    --conf spark.sql.hive.metastorePartitionPruning=true \
    --conf spark.sql.shuffle.partitions=480 \
    --conf spark.sql.sources.parallelPartitionDiscovery.threshold=120 \
    --conf spark.sql.sources.parallelPartitionDiscovery.parallelism=120 \
    --conf spark.sql.warehouse.dir=${SPARK_DIRS}/spark-warehouse \
    ${GLUTEN_OPTIONS} \
    ${SPARK_EXTRA_OPTIONS:-} \
    $@
