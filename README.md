# NCCL or RCCL on Slingshot - Getting Started

This repository provides utility scripts to simplify the process of setting up the runtime environment for running NCCL or RCCL on a Slingshot fabric. By automating the cloning, building, and configuration of required components, the scripts make it easy to get started with NCCL (for NVIDIA GPUs) or RCCL (for AMD GPUs) on Slingshot.

---

## Background

Setting up NCCL or RCCL on Slingshot involves several steps, including downloading source code, configuring dependencies, and compiling libraries. These scripts ameliorate the complexities by:

- Bringing together the lessons learned from a 4 month collaboration between HPE, Nvidia, and CSCS which addressed collective communications performance at scale, performance variability, and workload hangs.
- Automating the download and build process for [NVIDIA NCCL](https://github.com/NVIDIA/nccl) or [ROCm RCCL](https://github.com/ROCm/rccl), the [AWS OFI NCCL Plugin](https://github.com/aws/aws-ofi-nccl), and [NCCL Tests](https://github.com/NVIDIA/nccl-tests) or [RCCL Tests](https://github.com/ROCm/rccl-tests) (all optional).
- Parameterizing dependency versions like CUDA, ROCm, and Libfabric to make it easier to compose custom experiments with different library versions.
- The scripts always generate log files, so if you run out of scroll back buffer or there is a subtle difference in the build output, you have a better chance of catching the issue/behavior.

---

## Features

- **Automated Builds**: Clone and compile NCCL or RCCL, AWS OFI NCCL Plugin, and collective communications tests.
- **Customizable**: Specify library versions, directories, and build options via command-line arguments.
- **Dependency Management**: Ensures compatibility with CUDA/ROCm, Libfabric, and MPI implementations like MPICH.
- **Parallelism**: Leverage multi-threaded builds for faster setup.
- **Validation Ready**: Includes tests to verify the environment.

---

## Requirements

Before using the scripts, ensure the following are installed and available in your environment:

**For NCCL (NVIDIA GPUs):**
- **CUDA Toolkit**: Required for GPU acceleration.
- **Libfabric**: For communication over Slingshot.
- **MPI Implementation**: MPICH or another compatible MPI library.
- **Build Tools**: GCC/Clang, `git`, and `make`.

**For RCCL (AMD GPUs):**
- **ROCm**: Required for AMD GPU acceleration.
- **Libfabric**: For communication over Slingshot.
- **MPI Implementation**: MPICH or another compatible MPI library.
- **Build Tools**: GCC/Clang, `git`, and `make`.


---

## Quick Start

> **TL;DR** — clone this repo, load the right modules, run the build script,
> source `ccl_env.sh`, then launch your test.

**NCCL (NVIDIA GPUs):**
```bash
git clone https://github.com/HewlettPackard/shs-ccl-docs.git
cd shs-ccl-docs
module load cudatoolkit PrgEnv-cray && module swap cray-mpich cray-mpich-abi
./nccl/build_nccl_environment.sh          # builds to ./nccl/build, ./aws-ofi-nccl/src/.libs, ./nccl-tests/build
source ccl_env.sh
export NCCL_HOME=$(pwd)/nccl/build
export LD_LIBRARY_PATH=$(pwd)/aws-ofi-nccl/src/.libs:$NCCL_HOME:$LD_LIBRARY_PATH
cd nccl-tests/build
# Adjust --ntasks-per-node to match GPUs per node and --cpus-per-task accordingly
srun --ntasks-per-node=4 --cpus-per-task=72 --network=disable_rdzv_get ./all_reduce_perf -b 8 -e 4G -f 2
```

**RCCL (AMD GPUs):**
```bash
git clone https://github.com/HewlettPackard/shs-ccl-docs.git
cd shs-ccl-docs
module load rocm PrgEnv-cray && module swap cray-mpich cray-mpich-abi
./rccl/build_rccl_environment.sh          # builds to ./rccl/build/release, ./aws-ofi-rccl/lib, ./rccl-tests/build
source ccl_env.sh
export RCCL_HOME=$(pwd)/rccl/build/release
export LD_LIBRARY_PATH=$(pwd)/aws-ofi-rccl/lib:$RCCL_HOME:$LD_LIBRARY_PATH
cd rccl-tests/build
# Adjust --ntasks-per-node to match GPUs per node and --cpus-per-task accordingly
srun --ntasks-per-node=4 --cpus-per-task=72 --network=disable_rdzv_get ./all_reduce_perf -b 8 -e 4G -f 2
```

> **Note:** `ccl_env.sh` sets `NCCL_NET`, which forces the network transport.
> Do **not** source it for single-node Slurm runs — it will cause unnecessary
> VNI allocation. See [Validation](#validation) for details.

---

## Usage

### Pre-Flight Steps - Loading necessary modules (NCCL)
```
module load cudatoolkit
module load PrgEnv-cray
module swap cray-mpich cray-mpich-abi
```

### Pre-Flight Steps - Loading necessary modules (RCCL)
```
module load rocm
module load PrgEnv-cray
module swap cray-mpich cray-mpich-abi
```

The scripts live in the `nccl/` and `rccl/` subdirectories and can be
run with no command-line arguments, or with options to override defaults.
Run them from the directory you want to use as the build base:
`./nccl/build_nccl_environment.sh [options]` for NCCL builds
`./rccl/build_rccl_environment.sh [options]` for RCCL builds

### Options

| Option                        | Description                                                                                  | Default                         |
|-------------------------------|----------------------------------------------------------------------------------------------|---------------------------------|
| `-b, --base-dir <path>`       | Base directory for builds                                                                    | Current directory (`pwd`)       |
| `-l, --libfabric-path <path>` | Path to the Libfabric installation                                                           | `/opt/cray/libfabric/1.22.0`    |
| `-p, --parallelism <threads>` | Number of threads for parallel builds                                                        | 16                              |
| `-n, --nccl-version <version>`| NCCL version to build                                                                        | `v2.27.7-1`                     |
| `-r, --rccl-version <version>`| RCCL version to build                                                                        | `rocm-6.4.0`                    |
| `-a, --aws-version <version>` | AWS OFI NCCL plugin version to build                                                         | `v1.19.0`                       |
| `--log-dir <path>`            | Directory to save the build log file                                                         | `<base-dir>/logs`               |
| `--skip-clone`                | Skip cloning repositories (use existing directories)                                         | Disabled                        |
| `--skip-tests`                | Skip cloning and building tests (NCCL or RCCL)                                         | Disabled                        |
| `-h, --help`                  | Give a little help                                                                           | N/A                             |

> **Note on `--libfabric-path`:** The default path (`/opt/cray/libfabric/1.22.0`) uses
> upstream Libfabric versioning. On systems running Cray Slingshot Host Software (SHS),
> the directory name under `/opt/cray/libfabric/` reflects the **SHS release** rather than
> the upstream Libfabric version. Run `ls /opt/cray/libfabric/` on your compute node to
> discover the installed version, then pass it with `-l`. For example, SHS 2.3.1 ships
> Libfabric 1.29.1 and installs it at `/opt/cray/libfabric/2.3.1`.
>
> The build scripts must be executed on a **compute node** (e.g. via `srun --pty bash`
> or an `sbatch` job), because the required modules (`CUDA_HOME`, `ROCM_PATH`,
> `MPICH_DIR`) are only available in the compute-node environment.

---

## Example Usage

### NCCL Examples:

1. **Default Build**:
```
./nccl/build_nccl_environment.sh
```

2. **Custom Build Directory and Parallelism**:
You can pass a custom build directory and also change the build parallelism (note that there are diminishing marginal returns on increasing the number of build threads)
```
./nccl/build_nccl_environment.sh --base-dir /path/to/build/directory --parallelism 32
```
3. **Use Pre-existing Repositories**:
This option can be leveraged if you are providing your own repositories or don't need to clone the repositories because you already have done so previously.
```
./nccl/build_nccl_environment.sh --skip-clone
```
4. **Skip Tests**:
In case you don't want to clone and build the NCCL or RCCL tests.
```
./nccl/build_nccl_environment.sh --skip-tests
```

### RCCL Examples:

1. **Default Build**:
```
./rccl/build_rccl_environment.sh
```

2. **Custom ROCm Version**:
```
./rccl/build_rccl_environment.sh --rccl-version rocm-6.4.0
```

---

## Output

Upon successful execution, the following components will be available:

### NCCL Build Output:

| Component                | Path                                                                 |
|--------------------------|----------------------------------------------------------------------|
| NCCL build artifacts     | `<base-dir>/nccl/build`                                             |
| AWS OFI NCCL plugin      | `<base-dir>/aws-ofi-nccl/src/.libs`                                 |
| NCCL Tests (if built)    | `<base-dir>/nccl-tests/build`                                       |

### RCCL Build Output:

| Component                | Path                                                                 |
|--------------------------|----------------------------------------------------------------------|
| RCCL build artifacts     | `<base-dir>/rccl/build/release`                                     |
| AWS OFI RCCL plugin      | `<base-dir>/aws-ofi-rccl/lib`                                       |
| RCCL Tests (if built)    | `<base-dir>/rccl-tests/build`                                       |

Additionally, a timestamped log file will be saved in the log directory for debugging/troubleshooting.

---

## Validation

To verify the environment is set up correctly, run the appropriate NCCL or RCCL tests using the following commands (adjust parameters as needed):

### NCCL Validation

Setup Environment with build artifacts
```
# Setting up paths to dependencies
export NCCL_HOME=$(pwd)/nccl/build
export AWS_OFI_NCCL_HOME=$(pwd)/aws-ofi-nccl/src/.libs
export NCCL_TESTS_HOME=$(pwd)/nccl-tests/build

export LD_LIBRARY_PATH=$NCCL_HOME:${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH=$AWS_OFI_NCCL_HOME:${LD_LIBRARY_PATH}
export PATH=${PATH}:$NCCL_TESTS_HOME
```

Setup NCCL - Slingshot variables

> **Note:** `ccl_env.sh` sets `NCCL_NET`, which forces NCCL to use the network
> transport. Do not source this file (or unset `NCCL_NET` afterward) for
> single-node Slurm runs, as it will cause unnecessary VNI allocation.

```source``` [ccl_env.sh](ccl_env.sh)

Run NCCL-Tests
```
cd <base-dir>/nccl-tests/build
# --ntasks-per-node should equal the number of GPUs per node.
# --cpus-per-task should be total_cpus_per_node / ntasks_per_node.
srun --ntasks-per-node=4 --cpus-per-task=72 --network=disable_rdzv_get ./all_reduce_perf -b 8 -e 4G -f 2
```

### RCCL Validation

Setup Environment with build artifacts
```
# Setting up paths to dependencies
export RCCL_HOME=$(pwd)/rccl/build/release
export AWS_OFI_RCCL_HOME=$(pwd)/aws-ofi-rccl/lib
export RCCL_TESTS_HOME=$(pwd)/rccl-tests/build

export LD_LIBRARY_PATH=$RCCL_HOME:${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH=$AWS_OFI_RCCL_HOME:${LD_LIBRARY_PATH}
export PATH=${PATH}:$RCCL_TESTS_HOME
```

> **Note:** RCCL contains a known bug where it may search for `libnccl-net.so`
> instead of `librccl-net.so` when loading the network plugin. To work around
> this, explicitly point RCCL at the correct plugin:
> ```
> export NCCL_NET_PLUGIN=$AWS_OFI_RCCL_HOME/librccl-net.so
> ```

> **Note:** RCCL supports an external tuner plugin that can override the
> built-in collective algorithm and protocol selection. To load a custom tuner,
> set `NCCL_TUNER_PLUGIN` to the path of the tuner shared library:
> ```
> export NCCL_TUNER_PLUGIN=/path/to/librccl-tuner.so
> ```
> Without this variable, RCCL searches for `librccl-tuner.so` in
> `LD_LIBRARY_PATH` and falls back to its internal tuner if none is found.
> The message `TUNER/Plugin: Failed to find ncclTunerPlugin_v3 symbol, using
> internal tuner instead` is normal when no external tuner is configured.

> **Note:** To enable proxy-level profiling (e.g., for debugging network
> operation timing), set `NCCL_PROXY_PROFILE` to a file path. RCCL will
> write a Chrome trace-format JSON file that can be loaded in
> `chrome://tracing`:
> ```
> export NCCL_PROXY_PROFILE=/tmp/rccl_proxy_trace.json
> ```

Setup RCCL - Slingshot variables

> **Note:** `ccl_env.sh` sets `NCCL_NET`, which forces NCCL/RCCL to use the
> network transport. Do not source this file (or unset `NCCL_NET` afterward)
> for single-node Slurm runs, as it will cause unnecessary VNI allocation.

```source``` [ccl_env.sh](ccl_env.sh)

Run RCCL-Tests
```
cd <base-dir>/rccl-tests/build
# --ntasks-per-node should equal the number of GPUs per node.
# --cpus-per-task should be total_cpus_per_node / ntasks_per_node.
# Ensure the ROCm module matching your build is loaded so that libamdhip64.so
# and librccl.so are on LD_LIBRARY_PATH (e.g. module load rocm/6.3.3).
srun --ntasks-per-node=4 --cpus-per-task=72 --network=disable_rdzv_get ./all_reduce_perf -b 8 -e 4G -f 2
```

## Troubleshooting

1. **Missing Environment Variables**:
   - **NCCL**: Ensure `CUDA_HOME` and `MPICH_DIR` are set and verify the required modules are loaded.
   - **RCCL**: Ensure `ROCM_PATH` and `MPICH_DIR` are set and verify the required modules are loaded.

2. **Failed Cloning**:
   Check your connectivity to GitHub. Use `--skip-clone` if repositories are already cloned.

3. **Build Errors**:
   Review the log file in the log directory for detailed error messages.

4. **`error while loading shared libraries: libamdhip64.so.X: cannot open shared object file`**:
   The rccl-tests binary was built against a different ROCm major version than the one
   currently active. Load the ROCm module that matches your build before running the test,
   e.g. `module load rocm/6.3.3`. If the system default ROCm has been upgraded since you
   last built, rebuild with the new version using `--rccl-version rocm-<new_version>`.

---

## Links/Resources
- [NVIDIA NCCL](https://github.com/NVIDIA/nccl)
- [ROCm RCCL](https://github.com/ROCm/rccl)
- [AWS OFI NCCL Plugin](https://github.com/aws/aws-ofi-nccl)
- [NCCL Tests](https://github.com/NVIDIA/nccl-tests)
- [RCCL Tests](https://github.com/ROCm/rccl-tests)

---
