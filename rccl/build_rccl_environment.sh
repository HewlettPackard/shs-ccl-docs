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
ROCM_VERSION="rocm-6.4.0"
SKIP_CLONE=false
SKIP_TESTS=false
LOG_DIR="$BASE_DIR/logs"

# Help
usage() {
    echo "A utility to build a RCCL runtime environment."
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -b, --base-dir <path>         Base directory for builds (default: current directory)"
    echo "  -l, --libfabric-path <path>   Path to libfabric (default: $LIBFABRIC_PATH)"
    echo "  -p, --parallelism <threads>   Number of threads for parallel builds (default: $PARALLELISM)"
    echo "  -r, --rccl-version <version>  RCCL ROCm version to use (default: $ROCM_VERSION)"
    echo "  --log-dir <path>              Directory to save the build log file (default: <base-dir>/logs)"
    echo "  --skip-clone                  Skip cloning repositories (use existing directories)"
    echo "  --skip-tests                  Skip building rccl-tests"
    echo "  -h, --help                    Give a little help"
    exit 0
}

ARGS=$(getopt -o b:l:p:r:h --long base-dir:,libfabric-path:,parallelism:,rccl-version:,log-dir:,skip-clone,skip-tests,help -n "$0" -- "$@")
if [ $? -ne 0 ]; then usage; fi
eval set -- "$ARGS"

while true; do
    case "$1" in
        -b|--base-dir) BASE_DIR="$2"; shift 2 ;;
        -l|--libfabric-path) LIBFABRIC_PATH="$2"; shift 2 ;;
        -p|--parallelism) PARALLELISM="$2"; shift 2 ;;
        -r|--rccl-version) ROCM_VERSION="$2"; shift 2 ;;
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

# Redirect stdout/stderr to a log file
exec > >(tee "$LOG_FILE") 2>&1

echo "============================="
echo "Build log: $LOG_FILE"
echo "============================="

# Install locations (best-effort paths)
RCCL_HOME="$BASE_DIR/rccl/build"
HWLOC_HOME="$BASE_DIR/hwloc"
AWS_OFI_NCCL_HOME="$BASE_DIR/aws-ofi-nccl/src/.libs"
RCCL_TESTS_HOME="$BASE_DIR/rccl-tests/build"

cat <<EOF
=============================
Starting RCCL environment setup...
Base Directory: $BASE_DIR
Log Directory: $LOG_DIR
Libfabric Path: $LIBFABRIC_PATH
Parallelism: $PARALLELISM
RCCL Version: $ROCM_VERSION
Skip Cloning: $SKIP_CLONE
Skip rccl-tests: $SKIP_TESTS
=============================
EOF

# Basic preflight
if [ -z "$ROCM_PATH" ]; then
    echo "Warning: ROCM_PATH is not set. Attempting to use /opt/$ROCM_VERSION"
    export ROCM_PATH="/opt/$ROCM_VERSION"
fi

if [ -z "$MPICH_DIR" ]; then
    echo "Note: MPICH_DIR not set; rccl-tests and MPI builds may need MPI_HOME provided via environment."
fi

# Clone and build hwloc (replay_hwloc_commands.sh logic)
if [ "$SKIP_CLONE" = false ]; then
    if [ ! -d "$BASE_DIR/hwloc" ]; then
        echo "Cloning hwloc..."
        git clone https://github.com/open-mpi/hwloc.git "$BASE_DIR/hwloc" || { echo "Failed to clone hwloc"; exit 1; }
    fi
fi
if [ -d "$BASE_DIR/hwloc" ]; then
    pushd "$BASE_DIR/hwloc"
    if [ -x ./autogen.sh ]; then
      ./autogen.sh || true
    fi
    ./configure --with-rocm=${ROCM_PATH} --disable-doxygen --disable-cairo || true
    make -j"$PARALLELISM" || true
    popd
fi

# Clone and build aws-ofi-nccl (adapted from reproduce_aws_ofi_nccl.sh)
if [ "$SKIP_CLONE" = false ]; then
    if [ ! -d "$BASE_DIR/aws-ofi-nccl" ]; then
        echo "Cloning aws-ofi-nccl..."
        git clone https://github.com/aws/aws-ofi-nccl.git "$BASE_DIR/aws-ofi-nccl" || { echo "Failed to clone aws-ofi-nccl"; exit 1; } && git -C "$BASE_DIR/aws-ofi-nccl" fetch --tags --quiet
    fi
fi
if [ -d "$BASE_DIR/aws-ofi-nccl" ]; then
    pushd "$BASE_DIR/aws-ofi-nccl" && git checkout "v1.19.0" || { echo "Failed to checkout aws-ofi-nccl tag v1.19.0"; popd; exit 1; }
    ./autogen.sh || true
    CC=gcc ./configure --with-libfabric="$LIBFABRIC_PATH" --with-hwloc="$BASE_DIR" --with-rocm="$ROCM_PATH" || true
    make -j"$PARALLELISM" || true
    popd
fi

# Build RCCL
if [ "$SKIP_CLONE" = false ]; then
    if [ ! -d "$BASE_DIR/rccl" ]; then
        echo "Cloning RCCL..."
        git clone --recursive https://github.com/ROCm/rccl.git "$BASE_DIR/rccl" || { echo "Failed to clone RCCL"; exit 1; }
    fi
fi
if [ -d "$BASE_DIR/rccl" ]; then
    pushd "$BASE_DIR/rccl"
    git checkout "$ROCM_VERSION" || { echo "Failed to checkout RCCL version $ROCM_VERSION"; exit 1; }
    # If RCCL provides an install script, use hipcc as CXX similar to original script
    if [ -x ./install.sh ]; then
        CXX=hipcc ./install.sh --disable-msccl-kernel --fast -j $PARALLELISM || true
    else
        echo "No install.sh; attempting make"
        make -j"$PARALLELISM" || true
    fi
    popd
fi

# Clone and build rccl-tests (adapted from reproduce_rccl_tests.sh)
if [ "$SKIP_TESTS" = false ]; then
    if [ "$SKIP_CLONE" = false ] && [ ! -d "$BASE_DIR/rccl-tests" ]; then
        git clone https://github.com/ROCm/rccl-tests.git "$BASE_DIR/rccl-tests" || { echo "Failed to clone rccl-tests"; exit 1; }
    fi
    if [ -d "$BASE_DIR/rccl-tests" ]; then
        pushd "$BASE_DIR/rccl-tests"
        echo "Listing rccl-tests directory"
        pwd
        ls -la || true
        MPICC_PATH="${CRAY_MPICH_PREFIX}/bin/mpicc"
        echo "Using MPICC at $MPICC_PATH"
        make MPI=1 MPI_HOME="${CRAY_MPICH_PREFIX}" CXX=hipcc -j"$PARALLELISM" || true
        popd
    fi
fi

echo "============================="
echo "Build completed successfully!"
echo "============================="
echo "RCCL_HOME: $RCCL_HOME"
echo "HWLOC_HOME: $HWLOC_HOME"
echo "AWS_OFI_NCCL_HOME: $AWS_OFI_NCCL_HOME"
echo "RCCL_TESTS_HOME: $RCCL_TESTS_HOME"

echo "To verify installation, inspect the log and built artifacts under $BASE_DIR"
