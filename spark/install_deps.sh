#!/bin/bash

set -euo pipefail

DELIM="================================================================================"

if [ `id -u` != 0 ] ; then
    echo "Must be run as root! Please add sudo."
    exit 1
fi

# Install utilities
apt install -y unzip bc

# Install Java 11
apt install -y openjdk-11-jdk

# Install pyspark
pip3 install pyspark==3.5.4

echo $DELIM
echo "Installed dependencies."
echo "Make sure to set: JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64"
echo $DELIM
