#!/bin/bash

set -euo pipefail

DELIM="================================================================================"
SPARK_TPCDS_ZIP_NAME=spark-tpcds-datagen-master
TPCDS_QUERIES_ZIP_NAME=tpcds-master
TPCDS_GEN_DIR=$(mktemp -d -t tpcds-gen-XXXXXXXX)
TPCDS_WORK_DIR=${TPCDS_WORK_DIR:-$(mktemp -d -t tpcds-data-XXXXXXXX)}
TPCDS_DATA_DIR=$TPCDS_WORK_DIR/tpcds-sf1
SCALE_FACTOR=1

if [ -z ${SPARK_HOME:-} ]; then
    echo "Please set SPARK_HOME."
    exit 1
fi

if [ -z ${JAVA_HOME:-} ]; then
    echo "Please set JAVA_HOME."
    exit 1
fi

if [ ! -d ${SPARK_HOME:-} ]; then
    echo "SPARK_HOME folder doesn't exist: $SPARK_HOME."
    exit 1
fi

if [ ! -d ${JAVA_HOME:-} ]; then
    echo "JAVA_HOME folder doesn't exist: $JAVA_HOME."
    exit 1
fi

echo $DELIM
echo "Downloading TPC-DS queries..."
echo $DELIM
mkdir -p $TPCDS_WORK_DIR
cd $TPCDS_WORK_DIR
curl https://codeload.github.com/Agirish/tpcds/zip/refs/heads/master --output $TPCDS_QUERIES_ZIP_NAME.zip
unzip $TPCDS_QUERIES_ZIP_NAME.zip
rm $TPCDS_QUERIES_ZIP_NAME.zip
mv tpcds-master tpcds-queries

echo $DELIM
echo "Downloading TPC-DS generator..."
echo $DELIM
cd $TPCDS_GEN_DIR
curl https://codeload.github.com/maropu/spark-tpcds-datagen/zip/refs/heads/master --output $SPARK_TPCDS_ZIP_NAME.zip

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
bin/dsdgen --output-location $TPCDS_DATA_DIR --scale-factor $SCALE_FACTOR --format parquet

echo "Removing temporary files..."
rm -r $TPCDS_GEN_DIR

echo $DELIM
echo "TPC-DS data successfully generated under $TPCDS_WORK_DIR."
echo "For further stages set:"
echo
echo "export TPCDS_DATA_DIR=$TPCDS_DATA_DIR"
echo "export TPCDS_QUERIES_DIR=$TPCDS_WORK_DIR/tpcds-queries"
echo $DELIM
