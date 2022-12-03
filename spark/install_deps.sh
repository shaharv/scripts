#!/bin/bash

set -euo pipefail

DELIM="================================================================================"

# Install utilities
apt install -y unzip bc

# Install Java 11
apt install -y openjdk-11-jdk

echo $DELIM
echo "Installed dependencies."
echo "Make sure to set: JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64"
echo $DELIM
