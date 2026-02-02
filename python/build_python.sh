#!/bin/bash

set -exuo pipefail

PYTHON_VER_MAJOR=3.11
PYTHON_VER=3.11.8

# Install prerequisite packages
sudo apt update
sudo apt install -y build-essential libssl-dev zlib1g-dev libncurses5-dev libncursesw5-dev \
  libreadline-dev libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev libexpat1-dev liblzma-dev tk-dev \
  libffi-dev wget

# Download Python source code
tmpdir=$(mktemp -d)
cd $tmpdir
wget https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz
tar -xvf Python-${PYTHON_VER}.tgz
cd Python-${PYTHON_VER}

# Build and install Python
./configure --enable-optimizations --prefix=/opt/python-${PYTHON_VER_MAJOR}
make -j$(nproc)
sudo make install
sudo ln -s /opt/python-${PYTHON_VER_MAJOR}/bin/python${PYTHON_VER_MAJOR} python${PYTHON_VER_MAJOR}
