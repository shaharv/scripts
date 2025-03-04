#!/bin/bash

set -eu

DELIM="================================================================================"
SCRIPT_NAME=$(readlink -f ${BASH_SOURCE[0]})
SCRIPT_DIR="$(dirname $SCRIPT_NAME)"

NUM_RESULTS=100 # Print up to 100 results by default
SCRIPT_PARAMS=()
BATCH_MODE=0

function usage {
    echo "Usage: $0 <path to query.sql> [spark-shell options]"
    echo "Options:"
    echo "  --batch         Run in batch mode (non-interactive)"
    echo "  --help          Show this usage"
}

function check_env_vars {
    if [ -z ${SPARK_HOME:-} ]; then
        echo "Please set SPARK_HOME."
        exit 1
    fi

    if [ -z ${TPCDS_DATA_DIR:-} ]; then
        echo "Please set TPCDS_DATA_DIR."
        exit 1
    fi
}

function parse_args {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    # First parameter is an .sql file with query to run
    SQL_FILE=$1
    shift

    # Check if --help is specified as the first parameter
    if [ $SQL_FILE = "--help" ]; then
        usage
        exit 1
    fi

    if [ ! -e $SQL_FILE ]; then
        echo "Error: input file \"$SQL_FILE\" does not exist."
        exit 1
    fi

    if [ -d $SQL_FILE ]; then
        echo "Error: \"$SQL_FILE\" is a folder. Please specify an input file."
        exit 1
    fi

    # Handle additional script parameters
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --help)
                usage
                exit 0
                ;;
            --batch)
                export BATCH_MODE=1
                ;;
            *)
                SCRIPT_PARAMS+=($OPT)
                ;;
        esac
        shift
    done
}

function run_query {
    # Prepare temp. query file to match run_spark_shell.sh requirements. The query is
    # loaded from file as: sql_query = Source.fromFile(query_file).getLines.mkString
    QUERY_NAME=$(basename $SQL_FILE)
    TEMP_SQL_FILE=$(mktemp -t tpcds-$QUERY_NAME-XXXXXXXX.sql)
    cp $SQL_FILE $TEMP_SQL_FILE
    sed -i '/^--.*/d' $TEMP_SQL_FILE         # delete comment lines
    sed -i 's/^\(.*\)/ \1/g' $TEMP_SQL_FILE  # add space character before each line

    export QUERY_FILE=$TEMP_SQL_FILE
    export PRINT_NUM_RESULTS=$NUM_RESULTS

    echo $DELIM
    echo "About to run SQL query $QUERY_NAME"
    echo $DELIM
    echo
    cat $SQL_FILE
    echo
    echo $DELIM
    echo "TPC-DS data location: $TPCDS_DATA_DIR"
    echo "Full query file path: $(realpath ${SQL_FILE})"
    echo

    if [[ "$BATCH_MODE" == "0" ]]; then
        read -p "Press enter to run the query."
    fi

    # Run spark-shell
    $SCRIPT_DIR/run_spark_shell.sh ${SCRIPT_PARAMS[@]} -i run_tpcds_query.scala
}

check_env_vars
parse_args $@
run_query
