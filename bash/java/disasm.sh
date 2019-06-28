#!/bin/bash

set -exuo pipefail

$JAVA_HOME/bin/javap -p -l -v -s -c $1
