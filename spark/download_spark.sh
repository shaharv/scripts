#!/bin/bash

set -euo pipefail

DELIM="================================================================================"
SPARK_VER=3.5.2
SPARK_DOWNLOAD_URL=https://archive.apache.org/dist/spark/spark-$SPARK_VER
SPARK_RELEASE=spark-$SPARK_VER-bin-hadoop3
SPARK_ZIP=$SPARK_RELEASE.tgz
SPARK_ASC_FILE=$SPARK_ZIP.asc
SPARK_SHA_FILE=$SPARK_ZIP.sha512

# Download spark into a new folder
echo $DELIM
echo "Downloading Spark $SPARK_VER..."
echo $DELIM
TEMP_DIR=$(mktemp -d -t spark-XXXXXXXX)
cd $TEMP_DIR
wget $SPARK_DOWNLOAD_URL/$SPARK_ASC_FILE
wget $SPARK_DOWNLOAD_URL/$SPARK_SHA_FILE
wget $SPARK_DOWNLOAD_URL/$SPARK_ZIP

# Verify the downloaded zip signature and hash based on instructions in:
# - https://www.apache.org/dyn/closer.lua/spark/spark-3.5.2/spark-3.5.2-bin-hadoop3.tgz
# - https://www.apache.org/info/verification.html
echo $DELIM
echo "Verifying downloaded zip..."
echo $DELIM
wget https://downloads.apache.org/spark/KEYS
gpg --import KEYS
gpg --verify $SPARK_ASC_FILE $SPARK_ZIP
sha512sum -c $SPARK_SHA_FILE
echo "sha512 checksum verified."

# Extract Spark
echo $DELIM
echo "Extracting Spark..."
echo $DELIM
tar xvf $SPARK_ZIP

# Finish
echo $DELIM
echo "Spark $SPARK_VER was extracted to $TEMP_DIR/$SPARK_RELEASE."
echo "For using Spark in this location: export SPARK_HOME=$TEMP_DIR/$SPARK_RELEASE"
echo $DELIM
