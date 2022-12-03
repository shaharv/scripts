#!/bin/bash

set -euo pipefail

DELIM="================================================================================"
SPARK_TPCDS_GEN_BRANCH=master
SPARK_TPCDS_ZIP_NAME=spark-tpcds-datagen-$SPARK_TPCDS_GEN_BRANCH
TPCDS_GEN_DIR=$(mktemp -d -t tpcds-gen-XXXXXXXX)
OUTPUT_DATA_DIR=$(mktemp -d -t tpcds-data-XXXXXXXX)
SCALE_FACTOR=1

if [ -z $SPARK_HOME ]; then
    echo "Please set SPARK_HOME."
    exit 1
fi

if [ -z $JAVA_HOME ]; then
    echo "Please set JAVA_HOME."
    exit 1
fi

echo $DELIM
echo "Downloading TPC-DS generator..."
echo $DELIM
cd $TPCDS_GEN_DIR
curl https://codeload.github.com/maropu/spark-tpcds-datagen/zip/refs/heads/$SPARK_TPCDS_GEN_BRANCH --output $SPARK_TPCDS_ZIP_NAME.zip

echo $DELIM
echo "Extracting TPC-DS generator..."
echo $DELIM
unzip $SPARK_TPCDS_ZIP_NAME.zip

echo $DELIM
echo "TPC-DS generator was extracted to $TPCDS_GEN_DIR/$SPARK_TPCDS_ZIP_NAME."
echo $DELIM

echo $DELIM
echo "Generating TPC-DS data for SF=$SCALE_FACTOR..."
echo $DELIM
cd $TPCDS_GEN_DIR/$SPARK_TPCDS_ZIP_NAME
bin/dsdgen --output-location $OUTPUT_DATA_DIR --scale-factor $SCALE_FACTOR --format parquet

echo $DELIM
echo "TPC-DS data successfully generated under $OUTPUT_DATA_DIR."
echo "For further stages set: export TPCDS_DATA_DIR=$OUTPUT_DATA_DIR"
echo $DELIM
