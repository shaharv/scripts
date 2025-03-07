#!/bin/bash

set -euo pipefail

DELIM="================================================================================"
SPARK_VER=${SPARK_VER:-3.5.2}
SPARK_BASE_URL=https://archive.apache.org/dist/spark/spark-$SPARK_VER
SPARK_RELEASE=spark-$SPARK_VER-bin-hadoop3
SPARK_TARBALL=$SPARK_RELEASE.tgz
SPARK_ASC_FILE=$SPARK_TARBALL.asc
SPARK_SHA_FILE=$SPARK_TARBALL.sha512

TEMP_DIR=$(mktemp -d -t spark-XXXXXXXX)
cd $TEMP_DIR

function import_apache_keys {
    wget https://downloads.apache.org/spark/KEYS
    gpg --import KEYS
}

function download_apache_component {
    local baseUrl=$1
    local tarFileName=$2
    local componentName=$3

    # Download the tarball and signature files
    echo $DELIM
    echo "Downloading $componentName..."
    echo $DELIM
    wget $baseUrl/$tarFileName.asc
    wget $baseUrl/$tarFileName.sha512
    wget $baseUrl/$tarFileName

    # Verify the downloaded tarball signature and hash based on instructions in:
    # - https://www.apache.org/dyn/closer.lua/spark/spark-3.5.2/spark-3.5.2-bin-hadoop3.tgz
    # - https://www.apache.org/info/verification.html
    echo $DELIM
    echo "Verifying $tarFileName..."
    echo $DELIM
    gpg --verify $tarFileName.asc $tarFileName
    sha512sum -c $tarFileName.sha512
    echo "sha512 checksum verified."

    # Extract the tarball
    echo $DELIM
    echo "Extracting Spark..."
    echo $DELIM
    tar xvf $tarFileName
}

import_apache_keys
download_apache_component $SPARK_BASE_URL $SPARK_TARBALL Spark

# Finish
echo $DELIM
echo "Spark $SPARK_VER was extracted to $TEMP_DIR/$SPARK_RELEASE."
echo "For using Spark in this location: export SPARK_HOME=$TEMP_DIR/$SPARK_RELEASE"
echo $DELIM
