#!/bin/bash

# Use this script for installing Boost on the system.

set -eou pipefail

if [ `id -u` != 0 ] ; then
    echo "Must be run as root! Please add sudo."
    exit 1
fi

# Boost 1.84.0
BOOST_VERSION="1.84.0"
BOOST_VERSION_NAME="boost_1_84_0"
BOOST_TARBALL_NAME="$BOOST_VERSION_NAME.tar.gz"

# Full boost libraries (137MB archive), hosted on sourceforge
BOOST_TARBALL="https://sourceforge.net/projects/boost/files/boost/$BOOST_VERSION/$BOOST_TARBALL_NAME"
BOOST_TARBALL_SHA256="a5800f405508f5df8114558ca9855d2640a2de8f0445f051fa1c7c3383045724"

# Arrow slim Boost version (11MB archive), hosted on apache.jfrog.
# For contents of the trimmed Boost, see:
# https://github.com/apache/arrow/blob/main/cpp/build-support/trim-boost.sh
# BOOST_TARBALL="https://apache.jfrog.io/artifactory/arrow/thirdparty/7.0.0/$BOOST_TARBALL_NAME"
# BOOST_TARBALL_SHA256="267e04a7c0bfe85daf796dedc789c3a27a76707e1c968f0a2a87bb96331e2b61"

# Download boost
TEMP_DIR=$(mktemp -d -t boost-$BOOST_VERSION-XXXXXXXX)
cd $TEMP_DIR
wget $BOOST_TARBALL
sha256sum $BOOST_TARBALL_NAME | grep $BOOST_TARBALL_SHA256
tar -xf $BOOST_TARBALL_NAME

# Install prerequisite packages
apt-get install -y build-essential g++ python-dev autotools-dev libicu-dev libbz2-dev

# Build boost
cd $TEMP_DIR/$BOOST_VERSION_NAME
./bootstrap.sh --prefix=/usr/
./b2 || true # Allow script to continue even if some boost targets failed

# Install boost.
# Headers are installed under /usr/include/boost
./b2 install
