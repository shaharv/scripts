#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(realpath $(dirname $0))"
PROJECT_PATH="${PROJECT_PATH:-$(realpath $SCRIPT_DIR/..)}"

# File types to exclude from spell check
EXCLUDED_FILE_EXTENSIONS=('.excalidraw' '.svg')

# List of words to ignore
IGNORED_WORDS="rela,stoll,upto"

function check_executables {
    if [ -z $(which python3) ]; then
        echo "Python is missing. Please install with 'apt install python3-pip'."
        exit 1
    fi
    if [ -z $(which pip) ]; then
        echo "pip is missing. Please install with 'apt install python3-pip'."
        exit 1
    fi
    if [ -z $(which codespell) ]; then
        echo "codespell is missing. Please install with 'pip install codespell'."
        exit 1
    fi
}

function run_codespell {
    # Get the base list of git project files to check using "git ls-files".
    cd "${PROJECT_PATH}"
    FILES=$(git ls-files --exclude-standard)

    # Exclude git submodules and specified file extensions from the list of files.
    GIT_SUBMODULES=$(git config --file .gitmodules --get-regexp path | awk '{ print $2 }' || true)
    FILTERED_FILES=""
    for FILE in ${FILES[@]}; do
        for GIT_SUBMODULE in ${GIT_SUBMODULES[@]}; do
            if [ "${FILE}" = "${GIT_SUBMODULE}" ]; then
                continue 2
            fi
        done
        for FILE_EXTENSION in ${EXCLUDED_FILE_EXTENSIONS[@]}; do
            if [[ "${FILE}" == *"${FILE_EXTENSION}" ]]; then
                continue 2
            fi
        done
        FILTERED_FILES+=(${FILE})
    done

    # Run code spell
    codespell ${FILTERED_FILES[@]} --ignore-words-list ${IGNORED_WORDS} 2>/dev/null
}

check_executables
run_codespell
echo "Spell check completed successfully."
