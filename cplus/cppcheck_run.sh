#!/bin/bash

set -eou pipefail

SCRIPT_DIR="$(realpath $(dirname $0))"
ROOT_DIR="${ROOT_DIR:-`pwd`}"
CPPCHECK_EXE=${CPPCHECK_EXE:-/usr/local/bin/cppcheck}
CORES=${CORES:-`nproc`}

CPPCHECK_ARGS=" \
    --language=c++ \
    --std=c++20 \
    --check-level=exhaustive \
    --enable=all \
    --error-exitcode=2 \
    --inline-suppr \
    --suppress=knownConditionTrueFalse \
    --suppress=missingInclude \
    --suppress=missingIncludeSystem \
    --suppress=redundantAssignment \
    --suppress=redundantInitialization \
    --suppress=returnByReference \
    --suppress=unknownMacro \
    --suppress=unusedStructMember \
    --suppress=useStlAlgorithm \
    --suppress=variableScope \
    --suppress=virtualCallInConstructor"

CPPCHECK_FILE_LIST=$(mktemp /tmp/cppcheck-filelist-XXXXXX.txt)
trap "rm -f ${CPPCHECK_FILE_LIST}" EXIT

# Prepare the list of source files
SRC_DIRS=(".")
for SRC_DIR in ${SRC_DIRS[@]}; do
    SRC_FILES=$(find ${ROOT_DIR}/${SRC_DIR} \( -name "*.cpp" -or -name "*.h" \) -and -not -name "CMake*.cpp" -and -not -name "*.pb.*")
    echo "$SRC_FILES" >> ${CPPCHECK_FILE_LIST}
done

# Run cppcheck
set -x
time ${CPPCHECK_EXE} -j${CORES} ${CPPCHECK_ARGS} --file-list=${CPPCHECK_FILE_LIST}
