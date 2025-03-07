#!/bin/bash

set -euo pipefail

DELIM="================================================================================"
SPARK_VERSION=${SPARK_VERSION:-3.5.2}
SPARK_MAJOR_VERSION=${SPARK_VERSION%.*} # Remove the 3rd digit
SPARK_MAJOR_VERSION_NO_DOTS=${SPARK_MAJOR_VERSION//./} # Remove the dots
SPARK_BASE_URL=https://archive.apache.org/dist/spark/spark-$SPARK_VERSION
SPARK_RELEASE=spark-$SPARK_VERSION-bin-hadoop3
SPARK_TARBALL=$SPARK_RELEASE.tgz
GLUTEN_VERSION=${GLUTEN_VERSION:-1.3.0}
GLUTEN_BASE_URL=https://dlcdn.apache.org/incubator/gluten/${GLUTEN_VERSION}-incubating
GLUTEN_TARBALL=apache-gluten-${GLUTEN_VERSION}-incubating-bin-spark${SPARK_MAJOR_VERSION_NO_DOTS}.tar.gz
GLUTEN_JAR=gluten-velox-bundle-spark${SPARK_MAJOR_VERSION}_2.12-centos_7_x86_64-${GLUTEN_VERSION}.jar

TEMP_DIR=$(mktemp -d -t spark-XXXXXXXX)
cd $TEMP_DIR

function download_apache_component {
    local baseUrl=$1
    local tarFileName=$2
    local componentName=$3
    local keysUrlPath=$4

    # Import verification keys
    wget https://downloads.apache.org/$keysUrlPath/KEYS
    gpg --import KEYS

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

download_apache_component $GLUTEN_BASE_URL $GLUTEN_TARBALL Gluten "incubator/gluten"
download_apache_component $SPARK_BASE_URL $SPARK_TARBALL Spark "spark"

# Move Gluten jar to Spark's jar folder
mv $TEMP_DIR/$GLUTEN_JAR $TEMP_DIR/$SPARK_RELEASE/jars

# Finish
echo $DELIM
echo "Spark $SPARK_VERSION was extracted to $TEMP_DIR/$SPARK_RELEASE."
echo "For using Spark in this location: export SPARK_HOME=$TEMP_DIR/$SPARK_RELEASE"
echo "Gluten jar location: $TEMP_DIR/$SPARK_RELEASE/$GLUTEN_JAR"
echo $DELIM
