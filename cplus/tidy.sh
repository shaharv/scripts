#!/bin/bash

set -eou pipefail

# Set parameters
ROOT_DIR=${ROOT_DIR:-`pwd`}
BUILD_TYPE=${BUILD_TYPE:-Debug}
BUILD_DIR=${BUILD_DIR:-$ROOT_DIR/build/$BUILD_TYPE}
SRC_DIR=${SRC_DIR:-$ROOT_DIR}
TARGET_BRANCH=${TARGET_BRANCH:-origin/master}

# Set constants
CLANG_TIDY="/usr/bin/clang-tidy"
RUN_CLANG_TIDY="/usr/bin/run-clang-tidy"
COMPILE_DB="compile_commands.json"
CORES=$(nproc)

# Initialize variables
FILE=""
VERBOSE=0
GIT_DIFF=0
TIDY_PID=""

function usage {
    echo "Usage: $0 [<option> [<option ... ]]"
    echo "Options:"
    echo "   --cores=<N>   : Number of clang-tidy instances to be run in parallel"
    echo "   --file=<file> : Run on a single file"
    echo "   --fix         : Apply clang-tidy suggested fixes"
    echo "   --git-diff    : Run on all .cpp files in the git diff"
    echo "   --profile     : Enable profiling of clang-tidy checks"
    echo "   --help        : Display this usage information"
    echo "   --verbose     : Enable verbose clang-tidy output"
}

function set_dirs {
    # ROOT_DIR is used for locating .clang-tidy and .git
    if [ -e $ROOT_DIR ]; then
        ROOT_DIR=$(realpath $ROOT_DIR)
    else
        echo "Error: $ROOT_DIR is not found. Please set the ROOT_DIR environment variable to the root path of the project."
        exit 1
    fi

    # SRC_DIR must be a full path for run-clang-tidy.py filtering
    if [ -e $SRC_DIR ]; then
        SRC_DIR=$(realpath $SRC_DIR)
    else
        echo "Error: $SRC_DIR is not found. Please set SRC_DIR to the root sources folder."
        exit 1
    fi

    # BUILD_DIR must be a full path for script to work from any folder
    if [ -e $BUILD_DIR ]; then
        BUILD_DIR=$(realpath $BUILD_DIR)
    else
        echo "Error: $BUILD_DIR is not found. Please set BUILD_DIR to the build folder of the project."
        exit 1
    fi

    # Set clang-tidy parameters with paths only after resolving dir paths to the real ones.

    # The header filter is a positive regular expression for including header files to process.
    # The source dir (root dir to analyze) absolute path is used as the filtering expression.
    # Note: the / after the path is important to filter out partial matches, for example for "src_ext"
    # to be skipped when SRC_DIR ends with "src".
    HEADER_FILTER=${HEADER_FILTER:-"$SRC_DIR/"}

    TIDY_ARGS="-header-filter $HEADER_FILTER -extra-arg=-Wno-deprecated -extra-arg=-Wno-deprecated-declarations"
    RUN_CLANG_TIDY_ARGS="-p $BUILD_DIR -clang-tidy-binary=$CLANG_TIDY"
    TIDY_ALL_JQ_FILTER=${TIDY_ALL_JQ_FILTER:-'endswith(".pb.h") or endswith(".pb.cc") or contains("build/") or contains("src_ext/") or contains("thirdparty/")'}
}

function parse_args {
    # Check for support script options in the beginning of the command line.
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --help)
                usage
                exit 0
                ;;
            --verbose)
                VERBOSE=1
                ;;
            --fix)
                TIDY_ARGS="$TIDY_ARGS -fix"
                ;;
            --git-diff)
                GIT_DIFF=1
                ;;
            --profile)
                TIDY_ARGS="$TIDY_ARGS --enable-check-profile"
                ;;
            --file=*)
                FILE=${OPT/--file=/}
                if [ "$FILE" = "" ]; then
                    echo "Error: --file must be followed by file path."
                    exit 1
                fi
                ;;
            --cores=*)
                CORES=${OPT/--cores=/}
                NUMBER_REGEX='^[0-9]+$'
                if ! [[ $CORES =~ $NUMBER_REGEX ]]; then
                    echo "Error: invalid cores number: $CORES"
                    exit 1
                fi
                RUN_CLANG_TIDY_ARGS="${RUN_CLANG_TIDY_ARGS} -j $CORES"
                ;;
            *)
                echo "Error: unknown option $OPT".
                exit 1
                ;;
        esac
        shift
    done
}

function strip_compile_commands_json {
    JSON_IN="$BUILD_DIR/$COMPILE_DB"
    JSON_TEMP="$BUILD_DIR/$COMPILE_DB.filtered"
    JSON_ORIG="$BUILD_DIR/$COMPILE_DB.orig"

    cp $JSON_IN $JSON_ORIG
    trap "echo 'Cleaning up...' && mv $JSON_ORIG $JSON_IN && rm -f $JSON_TEMP" EXIT

    # Filter compile_commands.json so that we only run clang-tidy on files of interest.
    # For example, we do not want to run on third_party code.
    jq "[.[] | select(.file | ($TIDY_ALL_JQ_FILTER) | not)]" < $JSON_IN > $JSON_TEMP
    mv $JSON_TEMP $JSON_IN
}

# Forward signal to child process and handle cleanup.
#
# After running the tidy command in the background, we wait for it to complete.
# This is required so that Ctrl+C will not break out of the command and script altogether
# (SIGINT will kill clang-tidy and the bash script itself before any trap command is executed).
#
# When the tidy command exits, due to Ctrl+C or normal completion, trap EXIT will be triggered
# and allow for cleanup to take place, such as removal of temporary files.
function kill_tidy {
    echo "Killing tidy processes..."
    pkill -KILL -P $TIDY_PID || true 2>/dev/null
    kill -KILL $TIDY_PID || true 2>/dev/null
    echo "Aborted."
}

function tidy_all {
    echo "Running clang-tidy on all source files."
    echo "Root dir    : $ROOT_DIR"
    echo "Source dir  : $SRC_DIR"
    echo "Build dir   : $BUILD_DIR"
    echo "Current dir : $(pwd)"
    echo "Cores       : $CORES"
    echo

    # Before running run-clang-tidy, remove irrelevant files from compile_commands.json
    strip_compile_commands_json

    RUN_CLANG_TIDY_BASE_CMD="$RUN_CLANG_TIDY $RUN_CLANG_TIDY_ARGS $TIDY_ARGS $SRC_DIR/*"
    echo "Executing command: $RUN_CLANG_TIDY_BASE_CMD"
    if [ "$VERBOSE" = "0" ]; then
        # Diagnostic warnings and errors are reported to stdout.
        # Other clang-tidy messages are reported to stderr.
        $RUN_CLANG_TIDY_BASE_CMD 2>/dev/null &
    else
        $RUN_CLANG_TIDY_BASE_CMD &
    fi
    TIDY_PID=$!
    wait $TIDY_PID
}

function tidy_single_file {
    FILE=$1
    echo "Running clang-tidy on a single file: $FILE"
    echo
    CLANG_TIDY_CMD="$CLANG_TIDY -config-file=$ROOT_DIR/.clang-tidy $TIDY_ARGS -p $BUILD_DIR $FILE"
    echo "Executing command: $CLANG_TIDY_CMD"
    if [ "$VERBOSE" = "0" ]; then
        $CLANG_TIDY_CMD 2>/dev/null &
    else
        $CLANG_TIDY_CMD &
    fi
    TIDY_PID=$!
    wait $TIDY_PID
}

# Run run-clang-tidy.py only on the .cpp files in the git diff. This is applicable only for .cpp
# files and not .h, because header files do not have compilation commands in compile_commands.json.
# The .cpp files in diff are appended to the command line and used for source files filtering.
function tidy_diff {
    readarray -t FILES_IN_DIFF <<< "$(git diff ${TARGET_BRANCH} --name-only)"
    CPP_FILES_FOR_TIDY=()
    for FILE in "${FILES_IN_DIFF[@]}"; do
        if [[ ${FILE} == *.cpp ]] && [ -e ${FILE} ]; then
            FILE_PATH=$(realpath ${FILE})
            # Only add files that are under SRC_DIR
            if [[ ${FILE_PATH} == ${SRC_DIR}* ]]; then
                CPP_FILES_FOR_TIDY+=($FILE_PATH)
            fi
        fi
    done
    NUM_CPP_FILES=${#CPP_FILES_FOR_TIDY[@]}
    if [ $NUM_CPP_FILES = 0 ]; then
        echo "No cpp files under SRC_DIR ${SRC_DIR} were found in git diff. Nothing to run."
        return
    fi
    echo "${NUM_CPP_FILES} cpp file(s) were found in git diff under SRC_DIR ${SRC_DIR}:"
    echo "${CPP_FILES_FOR_TIDY[@]}"
    echo
    RUN_CLANG_TIDY_BASE_CMD="$RUN_CLANG_TIDY $RUN_CLANG_TIDY_ARGS $TIDY_ARGS ${CPP_FILES_FOR_TIDY[@]}"
    echo "Executing command: $RUN_CLANG_TIDY_BASE_CMD"
    if [ "$VERBOSE" = "0" ]; then
        # Diagnostic warnings and errors are reported to stdout.
        # Other clang-tidy messages are reported to stderr.
        $RUN_CLANG_TIDY_BASE_CMD 2>/dev/null &
    else
        $RUN_CLANG_TIDY_BASE_CMD &
    fi
    TIDY_PID=$!
    wait $TIDY_PID
}

function check_executables {
    if ! [ -e $CLANG_TIDY ]; then
        echo "Error: $CLANG_TIDY is missing. Please run llvm_update_alternatives.sh."
        exit 1
    fi
    if ! [ -e $RUN_CLANG_TIDY ]; then
        echo "Error: $RUN_CLANG_TIDY is missing. Please run llvm_update_alternatives.sh."
        exit 1
    fi
}

function main {
    set_dirs
    parse_args $@
    check_executables

    trap kill_tidy SIGINT SIGTERM SIGHUP

    # Run clang-tidy from ROOT_DIR so that .clang-tidy is detected, regardless of the directory
    # from which the script was executed. Similarly it is required for running "git diff".
    cd $ROOT_DIR

    if [ "$FILE" != "" ]; then
        tidy_single_file $FILE
    else
        if [ ! -e "$BUILD_DIR/$COMPILE_DB" ]; then
            echo "Error: compilation database is missing: $BUILD_DIR/$COMPILE_DB."
            echo "Set BUILD_DIR to the project build dir. Ensure that -DCMAKE_EXPORT_COMPILE_COMMANDS=ON is set in CMake command line."
            exit 1
        fi
        if [ ! -e "$ROOT_DIR/.clang-tidy" ]; then
            echo "Error: $ROOT_DIR/.clang-tidy is not found. Please set ROOT_DIR to the root of the project."
            exit 1
        fi
        if [ "$GIT_DIFF" = "1" ]; then
            tidy_diff
        else
            tidy_all
        fi
    fi

    echo "All done."
}

main $@
