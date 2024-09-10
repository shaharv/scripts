#!/bin/bash

# Script for finding spelling errors in a git repository using codespell.
#
# Usage: spell_check.sh <dir>
#
# The above command will check spelling for all files under the <dir> folder, excluding
# specific file extensions (such as .csv and .json) and folders (such as thirdparty).
# <dir> is expected to be a git repository or a subfolder of it.

set -euo pipefail

if [ "${1:-}" = "" ]; then
    echo "Usage: $0 <dir>"
    exit 0
fi

ROOT_DIR=$1

# File types to exclude from spell check
EXCLUDED_FILE_EXTENSIONS=('.bin' '.csv' '.excalidraw' '.json' '.svg')

# List of words to ignore
IGNORED_WORDS="rela,ro,stoll,upto,thirdparty"

function check_executables {
    if [ -z $(which python3) ]; then
        echo "Python is missing. Please install with 'apt install python3-pip'."
        exit 1
    fi
    if [ -z $(which codespell) ]; then
        echo "codespell is missing. Please install with 'pip install codespell'."
        exit 1
    fi
}

function run_codespell {
    # Get the base list of files to check using "git ls-files". Exclude the folder "thirdparty".
    cd "${ROOT_DIR}"
    FILES=$(git ls-files --exclude-standard | grep -v thirdparty)

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
