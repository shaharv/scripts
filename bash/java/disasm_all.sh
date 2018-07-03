#!/bin/bash

set -exuo pipefail

CLASS_FILES=`find -maxdepth 1 -name "*.class"`

for CLASS_FILE in ${CLASS_FILES[*]}; do
  source disasm.sh $CLASS_FILE > $CLASS_FILE.txt
done
