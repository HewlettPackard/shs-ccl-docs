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
# rocm-systems is the unified super-repo containing both rccl and rccl-tests
ROCM_SYSTEMS_REPO="https://github.com/ROCm/rocm-systems.git"
AWS_OFI_VERSION="v1.18.0"

# Help
usage() {
    echo "A utility to build a RCCL runtime environment."
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -b, --base-dir <path>         Base directory for builds (default: current directory)"
    echo "  -l, --libfabric-path <path>   Path to libfabric (default: /opt/cray/libfabric/1.22)"
    echo "  -p, --parallelism <threads>   Number of threads for parallel builds (default: 16)"
    echo "  -r, --rccl-version <version>  RCCL ROCm version to use (default: rocm-6.4.0)"
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

# The rocm-systems repository is cloned into BASE_DIR/rocm-systems.
# rccl and rccl-tests source live under rocm-systems/projects/.
ROCM_SYSTEMS_DIR="$BASE_DIR/rocm-systems"
RCCL_SRC="$ROCM_SYSTEMS_DIR/projects/rccl"
RCCL_TESTS_SRC="$ROCM_SYSTEMS_DIR/projects/rccl-tests"

# Build output locations
# install.sh builds into build/release inside the source tree
RCCL_HOME="$RCCL_SRC/build/release"
HWLOC_HOME="$BASE_DIR/hwloc"
AWS_OFI_NCCL_HOME="$BASE_DIR/aws-ofi-nccl/src/.libs"
RCCL_TESTS_HOME="$RCCL_TESTS_SRC/build"

# Basic preflight: ROCM_PATH
if [ -z "$ROCM_PATH" ]; then
    echo "Warning: ROCM_PATH is not set. Attempting to use /opt/$ROCM_VERSION"
    export ROCM_PATH="/opt/$ROCM_VERSION"
fi

# Confirm cmake >= 3.22 (required for --toolchain flag used by rccl/install.sh)
CMAKE_VERSION=$(cmake --version 2>/dev/null | awk 'NR==1{print $3}')
CMAKE_MAJOR=$(echo "$CMAKE_VERSION" | cut -d. -f1)
CMAKE_MINOR=$(echo "$CMAKE_VERSION" | cut -d. -f2)
if [ "${CMAKE_MAJOR:-0}" -lt 3 ] || { [ "${CMAKE_MAJOR:-0}" -eq 3 ] && [ "${CMAKE_MINOR:-0}" -lt 22 ]; }; then
    echo "ERROR: cmake >= 3.22 is required (found: ${CMAKE_VERSION:-none})."
    echo "       Run this script on a compute node: srun -N1 --ntasks=1 $0 [options]"
    exit 1
fi

# MPI: prefer CRAY_MPICH_PREFIX, fall back to MPICH_DIR
MPI_PREFIX="${CRAY_MPICH_PREFIX:-${MPICH_DIR:-}}"
if [ -z "$MPI_PREFIX" ]; then
    echo "Warning: Neither CRAY_MPICH_PREFIX nor MPICH_DIR is set."
    echo "         rccl-tests will be built without MPI support."
fi

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

# ──────────────────────────────────────────────
# Clone rocm-systems (contains both rccl and rccl-tests under projects/)
# ──────────────────────────────────────────────
if [ "$SKIP_CLONE" = false ]; then
    if [ ! -d "$ROCM_SYSTEMS_DIR" ]; then
        echo "Cloning rocm-systems (this may take a few minutes)..."
        git clone "$ROCM_SYSTEMS_REPO" "$ROCM_SYSTEMS_DIR" || {
            echo "ERROR: Failed to clone rocm-systems from $ROCM_SYSTEMS_REPO"
            exit 1
        }
    else
        echo "rocm-systems directory already exists at $ROCM_SYSTEMS_DIR; skipping clone."
    fi
fi

if [ ! -d "$RCCL_SRC" ]; then
    echo "ERROR: RCCL source not found at $RCCL_SRC"
    exit 1
fi
if [ ! -d "$RCCL_TESTS_SRC" ] && [ "$SKIP_TESTS" = false ]; then
    echo "ERROR: rccl-tests source not found at $RCCL_TESTS_SRC"
    exit 1
fi

# ──────────────────────────────────────────────
# Clone and build hwloc (needed by aws-ofi-nccl)
# ──────────────────────────────────────────────
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
    ./configure || true
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
    pushd "$BASE_DIR/aws-ofi-nccl" && git checkout "v1.18.0" || { echo "Failed to checkout aws-ofi-nccl tag v1.18.0"; popd; exit 1; }
    ./autogen.sh || true
    CC=gcc ./configure --with-libfabric="$LIBFABRIC_PATH" --with-hwloc="$BASE_DIR" --with-rocm="$ROCM_PATH" || true
    make -j"$PARALLELISM" || true
    popd
fi

# ──────────────────────────────────────────────
# Build RCCL from rocm-systems/projects/rccl
# ──────────────────────────────────────────────
echo "Building RCCL from $RCCL_SRC ..."
pushd "$RCCL_SRC"
# --fast: local GPU arch only, no collective trace, no MSCCL kernels (fastest build)
# -j: parallel jobs
./install.sh --fast -j "$PARALLELISM" || {
    echo "ERROR: RCCL install.sh failed"
    popd
    exit 1
}
popd
echo "RCCL build complete. Artifacts in $RCCL_HOME"

# ──────────────────────────────────────────────
# Build rccl-tests from rocm-systems/projects/rccl-tests
# ──────────────────────────────────────────────
if [ "$SKIP_TESTS" = false ]; then
    echo "Building rccl-tests from $RCCL_TESTS_SRC ..."
    pushd "$RCCL_TESTS_SRC"

    # rccl-tests Makefile uses NCCL_HOME to find rccl headers/library
    if [ -n "$MPI_PREFIX" ]; then
        make MPI=1 \
             MPI_HOME="$MPI_PREFIX" \
             NCCL_HOME="$RCCL_HOME" \
             CUSTOM_RCCL_LIB="$RCCL_HOME/librccl.so" \
             HIPCC="$ROCM_PATH/bin/hipcc" \
             -j"$PARALLELISM" || {
            echo "ERROR: rccl-tests build failed"; popd; exit 1
        }
    else
        make NCCL_HOME="$RCCL_HOME" \
             CUSTOM_RCCL_LIB="$RCCL_HOME/librccl.so" \
             HIPCC="$ROCM_PATH/bin/hipcc" \
             -j"$PARALLELISM" || {
            echo "ERROR: rccl-tests build failed (no MPI)"; popd; exit 1
        }
    fi
    popd
    echo "rccl-tests build complete. Artifacts in $RCCL_TESTS_HOME"
fi

echo "============================="
echo "Build completed successfully!"
echo "============================="
echo "RCCL_HOME: $RCCL_HOME"
echo "HWLOC_HOME: $HWLOC_HOME"
echo "AWS_OFI_NCCL_HOME: $AWS_OFI_NCCL_HOME"
echo "RCCL_TESTS_HOME: $RCCL_TESTS_HOME"

echo "To verify installation, inspect the log and built artifacts under $BASE_DIR"
