#!/bin/bash

# Script to wait for the specified TCP port to respond.

set -eou pipefail

SCRIPT_DIR="$(realpath $(dirname $0))"
PORT=22
TIMEOUT_SECONDS=10

function usage {
    echo "Polls until the specified TCP port is ready."
    echo
    echo "Options:"
    echo "  -h,--help              Show this message"
    echo "  -p,--port              TCP port to wait on. Default: $PORT"
    echo "  -t,--timeout           Timeout in seconds. Default: $TIMEOUT_SECONDS"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) usage; exit 0;;
        -p|--port) PORT=$2; shift 2;;
        -t|--timeout) TIMEOUT_SECONDS=$2; shift 2;;
        *) echo "Unrecognized argument: $1. Run --help for usage."; exit 1;;
    esac
done

echo "Waiting on port $PORT for $TIMEOUT_SECONDS seconds..."
for (( i=1; i<=$TIMEOUT_SECONDS; i++ )); do
    if nc -z 127.0.0.1 $PORT; then
        echo "Success."
        exit 0
    fi
    echo -n '.'
    sleep 1
done

echo
echo "Waiting for port: $PORT timed out."

exit 1
