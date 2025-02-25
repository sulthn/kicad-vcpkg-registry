#!/usr/bin/bash
set -e
export PATH=/usr/bin:$PATH
# Export HTTP(S)_PROXY as http(s)_proxy:
if [ "$HTTP_PROXY" ]; then
    export http_proxy=$HTTP_PROXY
fi
if [ "$HTTPS_PROXY" ]; then
    export https_proxy=$HTTPS_PROXY
fi

PATH_TO_BUILD_DIR="`cygpath "$1"`"
shift
VCPKG_INSTALL_BIN_DIR="`cygpath "$1"`"
shift
CONFIG_NAME=$1
shift

cd "$PATH_TO_BUILD_DIR"
echo "=== CONFIGURING ==="
echo "executing: python3 $@"
export PETSC_DIR=`pwd`
export PETSC_ARCH=$CONFIG_NAME
python3 "$@"
echo "=== BUILDING ==="
where make
env
cd "$PATH_TO_BUILD_DIR"
make all
echo "=== INSTALLING ==="
make install