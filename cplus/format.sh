#!/bin/bash

set -euo pipefail

CLANG_FORMAT_EXE=${CLANG_FORMAT_EXE:-`echo clang-format-18`}
DIRS=($(pwd))
METHOD=dry-run
DIFF_FILE=""
HAS_FAILED=0

function usage {
    echo "Usage: $0 [options] [list of folders]"
    echo
    echo "Format C++ source files using clang-format."
    echo "Formats all files under the current directory, unless one or more folders"
    echo "are specified as the last arguments."
    echo
    echo "Options:"
    echo "    -m,--method    Specify the desired operation."
    echo "                   Supported options: dry-run, in-place, diff."
    echo "    -h,--help      Show this usage."
}

function parseArgs {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help) usage; exit 0;;
            -m|--method) METHOD=$2; shift 2;;
            -*) echo "Error: unknown argument: $1"; exit 1;;
            *) DIRS=("$@"); break;;
        esac
    done
}

function runInPlace {
    local FILE=$1

    # Apply formatting fixes only if file is not a symlink
    if [[ -L "$FILE" ]]; then
        return
    fi

    # Always add a newline after namespace open brace and before namespace closing brace.
    # If newline already existed, clang-format will only keep a single newline.
    sed -i '/^namespace.*{$/{s/{$/&\n/}' $FILE
    sed -i '/^}\s*\/\/\s*namespace.*$/{s/^}/\n&/}' $FILE

    # Remove trailing whitespace
    sed -i 's/[ \t]*$//' $FILE

    # Run clang-format
    $CLANG_FORMAT_EXE -style=file -i $FILE
}

function runDiff {
    local FILE=$1

    # Write the formatted file to the temporary file
    if [[ ! -f $DIFF_FILE ]]; then
        DIFF_FILE=$(mktemp)
    fi

    $CLANG_FORMAT_EXE -style=file $FILE > $DIFF_FILE

    diff $FILE $DIFF_FILE && return 0 || return 1
}

function handleSingleFile {
    local FILE="$1"
    local METHOD="$2"

    case $METHOD in
        dry-run) echo "Will format $FILE.";;
        in-place) runInPlace $FILE;;
	diff) if ! runDiff $FILE; then
                echo "$FILE"
                HAS_FAILED=1
            fi
            ;;
        *) echo "Error: invalid method: $METHOD"; exit 1;;
    esac
}

function runFormat() {
    for CURR_DIR in ${DIRS[@]}; do
        if [ -f "$CURR_DIR" ]; then
            handleSingleFile "$CURR_DIR" "$METHOD"
            continue
        fi
        for EXTENSION in cpp h; do
            # Get the list of files under the current folder that match the specified extension,
            # excluding folders such as thirdparty, CMakeFiles, and build.
            FILES=$(find $CURR_DIR -name "*.$EXTENSION" \
                    -not -path "$CURR_DIR/thirdparty/*" \
                    -not -path "$CURR_DIR/build*/*" \
                    -not -path "$CURR_DIR/**/build*" \
                    -not -path "$CURR_DIR/**/CMakeFiles/*")
            if [[ ! -z $FILES ]]; then
                for FILE in $FILES; do
                    handleSingleFile "$FILE" "$METHOD"
                done
            fi
        done
    done
}

parseArgs $@
runFormat
exit $HAS_FAILED
