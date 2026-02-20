# HPE Slingshot Application Note: Running RCCL-Based Applications

## Summary

This document offers guidance for running AI applications on AMD GPUs using RCCL over HPE Slingshot NIC deployments.  Example libraries that depend on RCCL include PyTorch and TensorFlow. It covers the necessary background and configuration steps. This is an area of active development with improvements expected in future releases. To run these applications, you need at least the HPE Slingshot 2.1 release along with other specific dependencies detailed in this guide.

-----

## Background

### Understanding GPU Communication Libraries

High-performance computing (HPC) and AI applications depend on efficient communication between GPUs. NVIDIA GPUs use the NVIDIA Collective Communications Library (NCCL), while AMD GPUs use the ROCm Collective Communications Library (RCCL) for inter-GPU communication. This guide focuses on using Slingshot NIC RDMA capabilities with RCCL for maximum performance between GPUs on different nodes.

### AI Applications and Unique Communication Patterns

Many AI frameworks, such as PyTorch, use RCCL to communicate between GPUs on-node and between nodes. While both AI frameworks and traditional HPC applications use collective communications patterns for coordination and data exchange, RCCL does this by launching compute kernels which send large numbers of smaller messages over Libfabric. This unique behavior exercises the NIC and the Libfabric software stack differently than typical HPC codes.

### Memory Registration and HPE Slingshot's Approach

The distinct communication methods of AI applications heavily impact memory registration caching. HPE Slingshot's RDMA hardware relies on effective memory caching and a monitor to flush stale caches. To handle the application-specific nature of memory caching, the Slingshot NIC software supports three monitoring mechanisms: **userfaultfd**, **memhooks**, and **kdreg2**.

### The "Whole Stack" Challenge

Supporting RCCL applications is complex, involving dependencies across the entire software stack, from the OS and drivers to Libfabric and the application itself. HPE has worked to resolve numerous issues across this stack, especially those that appear at large scales (e.g., 2,000 GPUs). This highlights several key points:

  * **Libfabric Memory Registration**: HPE Slingshot uses Libfabric's memory registration, which may require more configuration than other NICs that offload this task to the application layer.
  * **Complex Interactions**: The many software components make it hard to test every possible combination. HPE validates specific combinations and encourages customers to use them to receive support.
  * **Application-Specific Issues**: The HPE Slingshot team addresses new issues on an application-by-application basis. Customers facing problems should file support tickets with detailed environment information.

-----

## RCCL Configuration Checklist

Here is a summary of the requirements to integrate HPE Slingshot GPU-NIC RDMA with the ROCm/RCCL stack.

1.  **Operating System**: A modern Linux kernel is required, specifically RHEL 8.6+ or SLES 15 SP4+.
2.  **HPE Slingshot Host Software**: Significant bug fixes and performance enhancements have been made in recent version of Slingshot Host Software and upgrading may resolve or reduce issues.
3.  **RCCL and OFI Libfabric Plugin**: The customer must build and install this plugin from the open-source GitHub project, ensuring version compatibility.
4.  **Libfabric (OFI) Environment Variables**: Specific environment variables are required for Libfabric when using RCCL.
5.  **RCCL and OFI-plugin Environment Variables**: These variables are critical for optimizing RCCL for both on-node and cross-fabric GPU communication.

-----

## RCCL Configuration Details

### Linux: 5.12 or later

Some applications, such as PyTorch, are not "fork safe," meaning they expect to use a single memory page for RDMA and for sharing data with child processes. The Linux 5.12 kernel introduced "copy on fork" capabilities to address this industry-wide challenge. This feature is present in SLES 15 SP4 and was backported to RHEL 8.6.

### HPE Slingshot Host Software

For the best performance and stability, always use the most recent version of the HPE Slingshot Host Software. Critical fixes for RCCL-based applications were integrated starting with the 2.1.x releases.

### OFI (Libfabric) Backend for RCCL

To enable high-performance RDMA, you must use the OFI Plug-In for Libfabric-to-RCCL. This open-source backend can be downloaded from GitHub at `https://github.com/ROCm/aws-ofi-rccl`. HPE and AMD have collaborated to ensure this plugin works with Slingshot NICs. Currently, users must build the code from the repository, as HPE does not provide pre-packaged RPMs.

### GPU Driver and User Stack Compatibility

The HPE Slingshot Host Software release notes contain a crucial compatibility matrix for GPU drivers and user-space libraries. For support, HPE will only assist with the specified combinations, as debugging issues with other versions is too complex due to deep interdependencies. [Notes for SHS 13.0.0](https://support.hpe.com/hpesc/public/docDisplay?docId=dp00006840en_us&page=release_notes/support_matrix.html)

### Essential Libfabric Environment Settings

Properly configuring Libfabric environment settings is **mandatory** for running RCCL applications effectively. Incorrect settings can be especially noticeable with the HPE Slingshot NIC due to its extensive hardware offload resources.

| Variable | Recommended Configuration For RCCL | Info |
| :--- | :--- | :--- |
| `HSA_FORCE_FINE_GRAIN_PCIE` | `1` | Enable peer-to-peer access to large BAR addressing support. |
| `FI_MR_CACHE_MONITOR` | `userfaultfd` | Sets the memory cache monitor to detect changes between virtual and physical memory pages. `kdreg2` is another valid option. |
| `FI_CXI_DISABLE_HOST_REGISTER` | `1` | Avoids ROCm allocation calls from the provider that may cause RCCL deadlocks. |
| `FI_CXI_DEFAULT_CQ_SIZE` | `131072` | Should be increased, especially for large jobs. |
| `FI_CXI_RDZV_PROTO` | `alt_read` | Use the alt_read rendevous protocool. |
| `FI_CXI_RX_MATCH_MODE` | `hybrid` | It allows the network stack to transition to software matching if hardware resources are exhausted. |
| `FI_CXI_RDZV_EAGER_SIZE` | `0` | Prevents sending data before the receiver is ready. |
| `FI_CXI_DEFAULT_TX_SIZE` | `2048` | Should be set especially for large jobs that are dependent on unexpected rendezvous messaging. |

**Note**: To use the `hybrid` rendezvous protocol, the driver property `rdzv_get_en` must be set to `0`. This can be done system-wide by a privileged user or, ideally, on a per-job basis through a job scheduler like Slurm (`--network=disable_rdzv_get`) or PBS Pro (`--disable-rdzv-get`).

-----

## Environment Settings for RCCL

Several environment variables, though prefixed with `NCCL_`, are required for AMD RCCL to function correctly and achieve good performance.

| Variable | Suggested Value | Info |
| :--- | :--- | :--- |
| `NCCL_CROSS_NIC` | `1` | Has been found to improve performance on large systems. |
| `NCCL_NET_GDR_LEVEL` | `PHB` | Required to enable RDMA between GPUs. |
| `NCCL_SOCKET_IFNAME` | `hsn0,hsn1,hsn2,hsn3` | Limits RCCL's bootstrap and socket communication to a specific interface.  These should match the interfaces available.  |
| `NCCL_NET` | `"AWS Libfabric"` | Ensures that RCCL will terminate if it fails to load the Libfabric plugin, preventing an undesirable fallback to sockets. |

-----

## Installing RCCL and Building `aws-ofi-rccl`

Most ROCm installations include RCCL, so you should use the pre-installed version and build the OFI plugin for Libfabric support. Below is an example script to build the plugin and the `rccl-tests` utility.

```bash
# Set environment variables for dependencies
export ROCM_HOME=/path/to/rocm
export OFI_HOME=/opt/cray/libfabric/1.15.2.0
export MPI_HOME=/opt/cray/pe/mpich/8.1.28/ofi/crayclang/17.0
export AWS_OFI_PLUGIN_HOME=/path/to/install/aws-ofi-plugin

# Build the OFI Plugin
echo "BUILDING OFI PLUGIN"
git clone --recurse-submodules https://github.com/ROCmSoftwarePlatform/aws-ofi-rccl.git
cd aws-ofi-rccl
./autogen.sh
CC=cc CXX=CC ./configure \
    --with-libfabric=${OFI_HOME} \
    --with-hip=${ROCM_HOME} \
    --with-mpi=${MPI_HOME} \
    --prefix=${AWS_OFI_PLUGIN_HOME}
make && make install
cd ..
rm -rf aws-ofi-rccl/

# Build RCCL Tests
echo "BUILDING RCCL TESTS"
git clone https://github.com/ROCmSoftwarePlatform/rccl-tests.git
cd rccl-tests
module load PrgEnv-amd rocm
cmake -DCMAKE_SYSTEM_NAME=CrayLinuxEnvironment -DUSE_MPI=ON -DROCM_PATH=${ROCM_PATH} .
make
cd ..
```

At runtime, ensure the compiled plugin (`librccl-net.so`) is in your `LD_LIBRARY_PATH`. Many deep learning frameworks include RCCL, so you may be using an older, unsupported version. It's recommended to upgrade or rebuild your packages from source with dynamic linking.

-----

## Troubleshooting Steps

### Low Performance

1.  **Check if the plugin library is in `LD_LIBRARY_PATH`**. If you see the message `No plugin found (librccl-net.so)`, it means RCCL could not locate the plugin.
2.  **Verify the plugin is loaded**. Set `export NCCL_DEBUG=INFO` and look for the log message `Loaded net plugin AWS Libfabric` for all ranks.
3.  **Confirm GDR is enabled**. Check that `echo $NCCL_NET_GDR_LEVEL` returns `PHB`.

### Filing a Support Ticket

When filing a ticket with the HPE Slingshot NIC team, please include the following:

  * HPE Slingshot Host Software version 
  * RCCL, MPI, and OFI plugin versions 
  * Application details and documentation 
  * `stdout` and `stderr` logs with `FI_LOG_LEVEL=info` and `FI_LOG_PROV=cxi` enabled 
  * Steps to reproduce the issue 

For RCCL-based applications, also enable `NCCL_DEBUG=info` and ensure the logs show a RCCL version of 2.14 or newer and that the network used is "AWS Libfabric".

Copyright Hewlett Packard Enterprise Development LP
