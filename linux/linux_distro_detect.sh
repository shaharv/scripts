#!/bin/bash

set -euo pipefail

function getField {
   local field=$1
   echo $(grep "\b$field\=" /etc/os-release | sed s/^$field\=// | tr -d '"')
}

# Extract Linux OS properties from /etc/os-release.
# This method is used instead of lsb_release, since lsb_release is not available for
# all distributions.
export LINUX_DISTRO=$(getField "ID")
export LINUX_RELEASE_PRETTY_NAME=$(getField "PRETTY_NAME")
export LINUX_RELEASE_NAME=$(getField "VERSION_CODENAME")
export LINUX_RELEASE_NUM=$(getField "VERSION_ID")
export LINUX_RELEASE_NUM_MAJOR=${LINUX_RELEASE_NUM%.*}

# Detect the package manager
if command -v apt > /dev/null; then
    INSTALL_CMD="apt-get install -y --no-install-recommends --allow-downgrades"
    UPDATE_CMD="apt-get update -y"
    REMOVE_CMD="apt-get remove -y"
    AUTOREMOVE_CMD="apt-get autoremove -y"
    PACKAGE_EXT="deb"
    PACKAGE_SUFFIX="_amd64"
    PACKAGE_SEP="_"
elif command -v yum >/dev/null; then
    if [[ $LINUX_RELEASE_NUM_MAJOR -ge 8 ]]; then
        INSTALL_CMD="yum install -y --allowerasing"
    else
        INSTALL_CMD="yum install -y"
    fi
    UPDATE_CMD="yum update -y"
    REMOVE_CMD="yum remove -y"
    AUTOREMOVE_CMD="yum autoremove -y"
    PACKAGE_EXT="rpm"
    PACKAGE_SUFFIX="-1.el8.x86_64"
    PACKAGE_SEP="-"
else
    echo "Unsupported package manager (not apt or yum)."
    exit 1
fi

if [ "${1:-}" = "--verbose" ]; then
    echo "Linux OS details:"
    echo "LINUX_DISTRO = $LINUX_DISTRO"
    echo "LINUX_RELEASE_PRETTY_NAME = $LINUX_RELEASE_PRETTY_NAME"
    echo "LINUX_RELEASE_NAME = $LINUX_RELEASE_NAME"
    echo "LINUX_RELEASE_NUM = $LINUX_RELEASE_NUM"
    echo "LINUX_RELEASE_MAJOR = $LINUX_RELEASE_NUM_MAJOR"
    echo
    echo "Package manager commands:"
    echo "INSTALL_CMD = $INSTALL_CMD"
    echo "UPDATE_CMD = $UPDATE_CMD"
    echo "REMOVE_CMD = $REMOVE_CMD"
    echo "AUTOREMOVE_CMD = $AUTOREMOVE_CMD"
    echo
    echo "Package properties:"
    echo "PACKAGE_EXT = $PACKAGE_EXT"
    echo "PACKAGE_SUFFIX = $PACKAGE_SUFFIX"
    echo "PACKAGE_SEP = $PACKAGE_SEP"
fi
