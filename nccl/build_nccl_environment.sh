# SPDX-FileCopyrightText: Copyright Hewlett Packard Enterprise Development LP
# SPDX-License-Identifier: MIT

#!/bin/bash
# Hewlett Packard Enterpise 2025
# Isa Wazirzada, Ryan Hankins
set -e
set -o pipefail

# Defaults
BASE_DIR=$(pwd)
LIBFABRIC_PATH="/opt/cray/libfabric/1.22.0"
PARALLELISM=16
NCCL_VERSION="v2.27.7-1"
AWS_OFI_NCCL_VERSION="v1.18.0"
SKIP_CLONE=false
SKIP_TESTS=false
LOG_DIR="$BASE_DIR/logs"

# Help
usage() {
    echo "A utility to build a NCCL runtime environment to run NCCL Tests on a Slingshot network."
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -b, --base-dir <path>         Base directory for builds (default: current directory)"
    echo "  -l, --libfabric-path <path>   Path to libfabric (default: /opt/cray/libfabric/1.22.0)"
    echo "  -p, --parallelism <threads>   Number of threads for parallel builds (default: 16)"
    echo "  -n, --nccl-version <version>  NCCL version to build (default: v2.27.7-1)"
    echo "  -a, --aws-version <version>   AWS OFI NCCL plugin version to build (default: v1.13.2-aws)"
    echo "  --log-dir <path>              Directory to save the build log file (default: <base-dir>/logs)"
    echo "  --skip-clone                  Skip cloning repositories (use existing directories)"
    echo "  --skip-tests                  Skip building NCCL Tests"
    echo "  -h, --help                    Give a little help"
    exit 0
}


ARGS=$(getopt -o b:l:p:n:a:h --long base-dir:,libfabric-path:,parallelism:,nccl-version:,aws-version:,log-dir:,skip-clone,skip-tests,help -n "$0" -- "$@")
if [ $? -ne 0 ]; then usage; fi
eval set -- "$ARGS"

while true; do
    case "$1" in
        -b|--base-dir) BASE_DIR="$2"; shift 2 ;;
        -l|--libfabric-path) LIBFABRIC_PATH="$2"; shift 2 ;;
        -p|--parallelism) PARALLELISM="$2"; shift 2 ;;
        -n|--nccl-version) NCCL_VERSION="$2"; shift 2 ;;
        -a|--aws-version) AWS_OFI_NCCL_VERSION="$2"; shift 2 ;;
        --log-dir) LOG_DIR="$2"; shift 2 ;;
        --skip-clone) SKIP_CLONE=true; shift ;;
        --skip-tests) SKIP_TESTS=true; shift ;;
        -h|--help) usage ;;
        --) shift; break ;;
        *) echo "Unexpected option: $1"; usage ;;
    esac
done


TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="${LOG_DIR}/build_${TIMESTAMP}.log"

mkdir -p "$LOG_DIR"

# Redirecting stdout/stderr to a log file
exec > >(tee "$LOG_FILE") 2>&1

echo "============================="
echo "Build log: $LOG_FILE"
echo "============================="

NCCL_HOME="$BASE_DIR/nccl/build"
AWS_OFI_NCCL_HOME="$BASE_DIR/aws-ofi-nccl/src/.libs"
NCCL_TESTS_HOME="$BASE_DIR/nccl-tests/build"

echo "============================="
echo "Starting NCCL environment setup..."
echo "Base Directory: $BASE_DIR"
echo "Log Directory: $LOG_DIR"
echo "Libfabric Path: $LIBFABRIC_PATH"
echo "Parallelism: $PARALLELISM"
echo "NCCL Version: $NCCL_VERSION"
echo "AWS OFI NCCL Plugin Version: $AWS_OFI_NCCL_VERSION"
echo "Skip Cloning: $SKIP_CLONE"
echo "Skip NCCL Tests: $SKIP_TESTS"
echo "============================="



# Preflight Checks
echo "Validating environment variables..."
if [ -z "$CUDA_HOME" ]; then
    echo "Error: CUDA_HOME is not set. Ensure the CUDA toolkit module is loaded correctly."
    exit 1
fi

if [ -z "$MPICH_DIR" ]; then
    echo "Error: MPICH_DIR is not set. Ensure the cray-mpich-abi module is loaded correctly."
    exit 1
fi

# Clone and build NCCL
if [ "$SKIP_CLONE" = false ]; then
    echo "Cloning and building NCCL..."
    if [ ! -d "nccl" ]; then
        git clone https://github.com/NVIDIA/nccl.git || { echo "Failed to clone NCCL repository"; exit 1; }
    fi
fi
cd nccl
git checkout "$NCCL_VERSION" || { echo "Failed to checkout NCCL version $NCCL_VERSION"; exit 1; }
make -j "$PARALLELISM" || { echo "Failed to build NCCL"; exit 1; }
cd ..

# Clone and build the AWS OFI NCCL plugin
if [ "$SKIP_CLONE" = false ]; then
    echo "Cloning and building AWS OFI NCCL plugin..."
    if [ ! -d "aws-ofi-nccl" ]; then
        git clone https://github.com/aws/aws-ofi-nccl.git || { echo "Failed to clone AWS OFI NCCL repository"; exit 1; } && git -C aws-ofi-nccl fetch --tags --quiet
    fi
fi
cd aws-ofi-nccl
git checkout "v1.18.0" || { echo "Failed to checkout AWS OFI NCCL tag v1.18.0"; exit 1; }
./autogen.sh || { echo "Failed to run autogen.sh for AWS OFI NCCL"; exit 1; }
CC=gcc ./configure --with-libfabric="$LIBFABRIC_PATH" --with-cuda="$CUDA_HOME" --disable-picky-compiler || { echo "Failed to configure AWS OFI NCCL"; exit 1; }
make -j "$PARALLELISM" || { echo "Failed to build AWS OFI NCCL"; exit 1; }
cd ..

# Clone and build the NCCL Tests
if [ "$SKIP_TESTS" = false ]; then
    echo "Cloning and building NCCL Tests..."
    if [ "$SKIP_CLONE" = false ] && [ ! -d "nccl-tests" ]; then
        git clone https://github.com/NVIDIA/nccl-tests.git || { echo "Failed to clone NCCL Tests repository"; exit 1; }
    fi
    cd nccl-tests
    # The nccl-tests/src Makefile needs NCCL_HOME to be set
    echo NCCL_HOME = $NCCL_HOME
    make MPI=1 MPI_HOME="$MPICH_DIR" -j "$PARALLELISM" || { echo "Failed to build NCCL Tests"; exit 1; }
    cd ..
fi

echo "============================="
echo "Build completed successfully!"
echo "============================="
echo "NCCL_HOME: $NCCL_HOME"
echo "AWS_OFI_NCCL_HOME: $AWS_OFI_NCCL_HOME"
echo "NCCL_TESTS_HOME: $NCCL_TESTS_HOME"
echo "To verify installation, try running the NCCL tests: "
echo "cd $NCCL_TESTS_HOME && srun --ntasks-per-node=4 --cpus-per-task=72 --gres=gpu:4 ./all_reduce_perf -b 8 -e 128M -f 2"
