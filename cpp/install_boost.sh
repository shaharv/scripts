#!/bin/bash -eux

# Script for building and installing Boost from source. Optionally choose between
# complete Boost distribution and Apache Arrow bundled trimmed Boost.
#
# For building Arrow with system Boost, instead of the bundled Boost, add
# -DBoost_SOURCE=SYSTEM to Arrow CMake build settings.
#
# Used to workaround Apache Arrow bundled boost checksum issue described in:
# https://github.com/apache/arrow/issues/34675

# Boost 1.75.0 (used by Arrow 8)
BOOST_VERSION="1.75.0"
BOOST_VERSION_NAME="boost_1_75_0"
BOOST_TARBALL_NAME="$BOOST_VERSION_NAME.tar.gz"

# Full boost libraries (137MB archive), hosted on sourceforge
BOOST_TARBALL="https://sourceforge.net/projects/boost/files/boost/$BOOST_VERSION/$BOOST_TARBALL_NAME"
BOOST_TARBALL_SHA256="aeb26f80e80945e82ee93e5939baebdca47b9dee80a07d3144be1e1a6a66dd6a"

# Arrow trimmed Boost version (11MB archive), hosted on apache.jfrog.
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
sudo apt-get install -y build-essential g++ python-dev autotools-dev libicu-dev libbz2-dev

# Build boost
cd $TEMP_DIR/$BOOST_VERSION_NAME
./bootstrap.sh --prefix=/usr/
./b2 || true # Allow script to continue even if some boost targets failed

# Install boost.
# Headers are installed under /usr/include/boost
sudo ./b2 install
