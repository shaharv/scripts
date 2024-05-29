#!/bin/bash

# Set system and profile limits for enabling core dumps.

set -euo pipefail

LIMITS_FILE=/etc/security/limits.conf
PROFILE_FILE=/etc/profile
ULIMIT_SETTING="ulimit -c unlimited"

function setGlobalLimit {
    USER=$1
    MODE=$2
    CORE_SETTING_FOR_USER="${USER} ${MODE} core unlimited"
    if ! grep -qx "^${CORE_SETTING_FOR_USER}" ${LIMITS_FILE}; then
        echo "Appending \"${CORE_SETTING_FOR_USER}\" to ${LIMITS_FILE}"
        echo "${CORE_SETTING_FOR_USER}" >> ${LIMITS_FILE}
    else
        echo "Note: ${LIMITS_FILE} already contains \"${CORE_SETTING_FOR_USER}\"."
    fi
}

function setGlobalLimits {
    if ! [ -e ${LIMITS_FILE} ]; then
        echo "Error: ${LIMITS_FILE} is missing. Could not set core limits."
        exit 1
    fi

    setGlobalLimit "*"    "soft"
    setGlobalLimit "*"    "hard"
    setGlobalLimit "root" "soft"
    setGlobalLimit "root" "hard"

    echo "Limits are set to enable coredumps."
}

function setUserLimits {
    if ! [ -e ${PROFILE_FILE} ]; then
        echo "Error: ${PROFILE_FILE} is missing. Could not set core limits."
        exit 1
    fi

    if ! grep -qx "^${ULIMIT_SETTING}" ${PROFILE_FILE}; then
        echo "Appending \"${ULIMIT_SETTING}\" to ${PROFILE_FILE}"
        echo -e "\n${ULIMIT_SETTING}" >> ${PROFILE_FILE}
    else
        echo "Note: ${PROFILE_FILE} already contains \"${ULIMIT_SETTING}\"."
    fi

    echo "User limits are set to enable coredumps."
}

function main {
    if [ `id -u` != 0 ] ; then
        echo "Must be run as root!"
        exit 1
    fi

    setGlobalLimits
    setUserLimits

    echo "----------------------------------------"
    echo "Done setting limits."
    echo "----------------------------------------"
}

main $@
