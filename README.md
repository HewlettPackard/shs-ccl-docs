# NCCL or RCCL on Slingshot - Getting Started

This repository provides utility scripts to simplify the process of setting up the runtime environment for running NCCL or RCCL on a Slingshot fabric. By automating the cloning, building, and configuration of required components, the scripts make it easy to get started with NCCL (for NVIDIA GPUs) or RCCL (for AMD GPUs) on Slingshot.

---

## Background

Setting up NCCL or RCCL on Slingshot involves several steps, including downloading source code, configuring dependencies, and compiling libraries. These scripts ameliorate the complexities by:

- Bringing together the lessons learned from a 4 month collaboration between HPE, Nvidia, and CSCS which addressed collective communications performance at scale, performance variability, and workload hangs.
- Automating the download and build process for [NVIDIA NCCL](https://github.com/NVIDIA/nccl) or [ROCm RCCL](https://github.com/ROCm/rocm-systems) (under `projects/rccl`), the [AWS OFI NCCL Plugin](https://github.com/aws/aws-ofi-nccl), and [NCCL Tests](https://github.com/NVIDIA/nccl-tests) or [RCCL Tests](https://github.com/ROCm/rocm-systems) (under `projects/rccl-tests`) (all optional).
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

The scripts can be run with no command line arguments, or one can override the default options:
`./build_nccl_environment.sh [options]` for NCCL builds
`./build_rccl_environment.sh [options]` for RCCL builds

### Options

| Option                        | Description                                                                                  | Default                         |
|-------------------------------|----------------------------------------------------------------------------------------------|---------------------------------|
| `-b, --base-dir <path>`       | Base directory for builds                                                                    | Current directory (`pwd`)       |
| `-l, --libfabric-path <path>` | Path to the Libfabric installation                                                           | `/opt/cray/libfabric/1.22.0`    |
| `-p, --parallelism <threads>` | Number of threads for parallel builds                                                        | 16                              |
| `-n, --nccl-version <version>`| NCCL version to build                                                                        | `v2.27.7-1`                     |
| `-r, --rccl-version <version>`| RCCL version to build                                                                        | `rocm-6.4.0`                    |
| `-a, --aws-version <version>` | AWS OFI NCCL plugin version to build                                                         | `v1.18.0`                       |
| `--log-dir <path>`            | Directory to save the build log file                                                         | `<base-dir>/logs`               |
| `--skip-clone`                | Skip cloning repositories (use existing directories)                                         | Disabled                        |
| `--skip-tests`                | Skip cloning and building tests (NCCL or RCCL)                                         | Disabled                        |
| `-h, --help`                  | Give a little help                                                                           | N/A                             |

---

## Example Usage

### NCCL Examples:

1. **Default Build**:
```
./build_nccl_environment.sh
```

2. **Custom Build Directory and Parallelism**:
You can pass a custom build directory and also change the build parallelism (note that there are diminishing marginal returns on increasing the number of build threads)
```
./build_nccl_environment.sh --base-dir /path/to/build/directory --parallelism 32
```
3. **Use Pre-existing Repositories**:
This option can be leveraged if you are providing your own repositories or don't need to clone the repositories because you already have done so previously.
```
./build_nccl_environment.sh --skip-clone
```
4. **Skip Tests**:
In case you don't want to clone and build the NCCL or RCCL tests.
```
./build_nccl_environment.sh --skip-tests
```

### RCCL Examples:

1. **Default Build**:
```
./build_rccl_environment.sh
```

2. **Custom ROCm Version**:
```
./build_rccl_environment.sh --rccl-version rocm-6.4.0
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
| RCCL build artifacts     | `<base-dir>/rocm-systems/projects/rccl/build/release`               |
| AWS OFI NCCL plugin      | `<base-dir>/aws-ofi-nccl/src/.libs`                                 |
| RCCL Tests (if built)    | `<base-dir>/rocm-systems/projects/rccl-tests/build`                 |

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

```source``` [ccl_env.sh](ccl_env.sh)

Run NCCL-Tests
```
cd <base-dir>/nccl-tests/build
srun --ntasks-per-node=4 --cpus-per-task=72 --network=disable_rdzv_get ./all_reduce_perf -b 8 -e 4G -f 2
```

### RCCL Validation

Setup Environment with build artifacts
```
# Setting up paths to dependencies
export RCCL_HOME=$(pwd)/rocm-systems/projects/rccl/build/release
export AWS_OFI_NCCL_HOME=$(pwd)/aws-ofi-nccl/src/.libs
export RCCL_TESTS_HOME=$(pwd)/rocm-systems/projects/rccl-tests/build

export LD_LIBRARY_PATH=$RCCL_HOME:${LD_LIBRARY_PATH}
export LD_LIBRARY_PATH=$AWS_OFI_NCCL_HOME:${LD_LIBRARY_PATH}
export PATH=${PATH}:$RCCL_TESTS_HOME
```

Setup RCCL - Slingshot variables

```source``` [ccl_env.sh](ccl_env.sh)

Run RCCL-Tests
```
cd <base-dir>/rccl-tests/build
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

---

## Links/Resources
- [NVIDIA NCCL](https://github.com/NVIDIA/nccl)
- [ROCm RCCL](https://github.com/ROCm/rocm-systems) (under `projects/rccl`)
- [AWS OFI NCCL Plugin](https://github.com/aws/aws-ofi-nccl)
- [NCCL Tests](https://github.com/NVIDIA/nccl-tests)
- [RCCL Tests](https://github.com/ROCm/rocm-systems) (under `projects/rccl-tests`)

---
