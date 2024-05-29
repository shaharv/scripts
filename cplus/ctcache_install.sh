#!/bin/bash

# This script installs the ctcache project - Cache for clang-tidy.
# https://github.com/matus-chochlik/ctcache
#
# The project is installed by default to /usr/local/ctcache, configurable using $CTCACHE_INSTALL_DIR.
# A wrapper script is created at /usr/bin/clang-tidy for invoking ctcache.
#
# For disabling ctcache after installation, set the environment variable CTCACHE_DISABLE=1.

set -euo pipefail

CLANG_TIDY_EXE=/usr/bin/clang-tidy
CTCACHE_INSTALL_DIR="/usr/local/ctcache"
CTCACHE_GIT_COMMIT=29b1f6428682302223402b283e4449ac337ae649 # master commit as of Oct 26, 2023
LLVM_VERSION=18
UNINSTALL=""

function usage {
    echo "Usage: $0 [--install-dir=<path>][--llvm-version=N][--uninstall][--help]"
    echo
    echo "Install or uninstall the ctcache tool."
}

function parse_args {
    while [[ $# -gt 0 ]]; do
        OPT="$1"
        case $OPT in
            --install-dir=*) CTCACHE_INSTALL_DIR=${OPT/--install-dir=/}; shift;;
            --llvm-version=*) LLVM_VERSION=${OPT/--llvm-version=/}; shift;;
            --uninstall) shift; UNINSTALL=1;;
            --help) usage; exit 0;;
            *) echo "Error: unknown argument: $1"; usage; exit 1;;
        esac
    done
}

function uninstall_ctcache {
    echo "Removing $CTCACHE_INSTALL_DIR..."
    rm -rf $CTCACHE_INSTALL_DIR

    echo "Updating $CLANG_TIDY_EXE..."
    rm -f $CLANG_TIDY_EXE
    PRIORITY=$(( $LLVM_VERSION * 100 ))
    update-alternatives --install $CLANG_TIDY_EXE clang-tidy $CLANG_TIDY_EXE-$LLVM_VERSION $PRIORITY

    echo "ctcache was removed."
}

function prepare {
    # Check for clang-tidy
    if ! which clang-tidy-$LLVM_VERSION >/dev/null; then
       echo "clang-tidy-$LLVM_VERSION is not found. Please install it by running \"./llvm_install.sh --version $LLVM_VERSION\"."
       exit 1
    fi

    # Check for run-clang-tidy
    if ! which run-clang-tidy-$LLVM_VERSION >/dev/null; then
       echo "run-clang-tidy-$LLVM_VERSION is not found. Please install it by running \"./llvm_install.sh --version $LLVM_VERSION\"."
       exit 1
    fi

    # Make sure this script is run as root with sudo.
    if [[ $EUID -ne 0 ]]; then
        echo "Please run this script as root with sudo."
        exit 1
    fi

    # Install script prerequisite packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends unzip curl

    # Remove previous installation folder if present
    if [ -e $CTCACHE_INSTALL_DIR ]; then
       echo "Destination $CTCACHE_INSTALL_DIR exists; removing previous installation."
       uninstall_ctcache
    fi
}

function install_ctcache {
    CTCACHE_TEMP_DIR=$(mktemp -d -t ctcache-temp-XXXXXX)
    trap "rm -rf $CTCACHE_TEMP_DIR" EXIT

    # Download and install ctcache
    echo "Installing ctcache to $CTCACHE_INSTALL_DIR..."
    mkdir -p $CTCACHE_INSTALL_DIR
    cd $CTCACHE_TEMP_DIR
    curl -L https://github.com/matus-chochlik/ctcache/archive/$CTCACHE_GIT_COMMIT.zip -o $CTCACHE_GIT_COMMIT.zip
    unzip $CTCACHE_GIT_COMMIT.zip
    mv $CTCACHE_TEMP_DIR/ctcache-$CTCACHE_GIT_COMMIT/* $CTCACHE_INSTALL_DIR
}

function create_wrapper_script {
    echo "Updating $CLANG_TIDY_EXE..."
    CTCACHE_TEMP_SCRIPT=$(mktemp -t ctcache-sh-XXXXXX)

    # Create the clang-tidy wrapper script, which will set needed variables and call ctcache.
    # Example for the generated script:
    #
    # !/bin/bash -eu
    # export CTCACHE_CLANG_TIDY=${CTCACHE_CLANG_TIDY:-/usr/bin/clang-tidy-18}
    # export CTCACHE_DIR=${CTCACHE_DIR:-$HOME/.ctcache}
    # /home/shahar/ctcache/clang-tidy "${@}"
    #
    cat > $CTCACHE_TEMP_SCRIPT <<- CLANG_TIDY_WRAPPER_SCRIPT
#!/bin/bash -eu
export CTCACHE_CLANG_TIDY=\${CTCACHE_CLANG_TIDY:-$CLANG_TIDY_EXE-$LLVM_VERSION}
export CTCACHE_DIR=\${CTCACHE_DIR:-\$HOME/.ctcache}
$CTCACHE_INSTALL_DIR/clang-tidy "\${@}"
CLANG_TIDY_WRAPPER_SCRIPT
    # End of generated script

    rm -f $CLANG_TIDY_EXE
    mv $CTCACHE_TEMP_SCRIPT $CLANG_TIDY_EXE
    chmod 755 $CLANG_TIDY_EXE
}

function main {
    parse_args $@
    if [ "$UNINSTALL" = "1" ]; then
        uninstall_ctcache
        exit 0
    fi
    prepare
    install_ctcache
    create_wrapper_script

    echo "Create /usr/bin/run-clang-tidy symlink..."
    ln -sf $(readlink -f /usr/bin/run-clang-tidy-$LLVM_VERSION) /usr/bin/run-clang-tidy

    echo "ctcache successfully installed."
}

main $@
