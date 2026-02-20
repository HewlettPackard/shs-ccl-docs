# HPE Slingshot Application Note: Running NCCL-Based Applications

## Summary

This document offers guidance for running AI applications on NVIDIA GPUs using NCCL over HPE Slingshot NIC deployments. Example libraries that depend on NCCL include PyTorch and TensorFlow. It covers the necessary background and configuration steps. This is an area of active development with improvements expected in future releases. To run these applications, you need at least the HPE Slingshot 2.1 release along with other specific dependencies detailed in this guide.

-----

## Background

### Understanding GPU Communication Libraries

High-performance computing (HPC) and AI applications depend on efficient communication between GPUs. NVIDIA GPUs use the NVIDIA Collective Communications Library (NCCL) for inter-GPU communication. This guide focuses on using Slingshot NIC RDMA capabilities with NCCL for maximum performance between GPUs on different nodes.

### AI Applications and Unique Communication Patterns

Many AI frameworks, such as PyTorch, use NCCL to communicate between GPUs on-node and between nodes. While both AI frameworks and traditional HPC applications use collective communications patterns for coordination and data exchange, NCCL does this by launching compute kernels which send large numbers of smaller messages over Libfabric. This unique behavior exercises the NIC and the Libfabric software stack differently than typical HPC codes.

### Memory Registration and HPE Slingshot's Approach

The distinct communication methods of AI applications heavily impact memory registration caching. HPE Slingshot's RDMA hardware relies on effective memory caching and a monitor to flush stale caches. To handle the application-specific nature of memory caching, the Slingshot NIC software supports three monitoring mechanisms: **userfaultfd**, **memhooks**, and **kdreg2**.

### The "Whole Stack" Challenge

Supporting NCCL applications is complex, involving dependencies across the entire software stack, from the OS and drivers to Libfabric and the application itself. HPE has worked to resolve numerous issues across this stack, especially those that appear at large scales (e.g., 2,000 GPUs). This highlights several key points:

  * **Libfabric Memory Registration**: HPE Slingshot uses Libfabric's memory registration, which may require more configuration than other NICs that offload this task to the application layer.
  * **Complex Interactions**: The many software components make it hard to test every possible combination. HPE validates specific combinations and encourages customers to use them to receive support.
  * **Application-Specific Issues**: The HPE Slingshot team addresses new issues on an application-by-application basis. Customers facing problems should file support tickets with detailed environment information.

-----

## NCCL Configuration Checklist

Here is a summary of the requirements to integrate HPE Slingshot GPU-NIC RDMA with the NVIDIA/NCCL stack.

1.  **Operating System**: A modern Linux kernel is required, specifically RHEL 8.6+ or SLES 15 SP4+.
2.  **HPE Slingshot Host Software**: Significant bug fixes and performance enhancements have been made in recent version of Slingshot Host Software and upgrading may resolve or reduce issues.
3.  **NCCL and OFI Libfabric Plugin**: The customer must build and install this plugin from the open-source GitHub project, ensuring version compatibility.
4.  **Libfabric (OFI) Environment Variables**: Specific environment variables are required for Libfabric when using NCCL.
5.  **NCCL and OFI-plugin Environment Variables**: These variables are critical for optimizing NCCL for both on-node and cross-fabric GPU communication.

-----

## NCCL Configuration Details

### Linux: 5.12 or later

Some applications, such as PyTorch, are not "fork safe," meaning they expect to use a single memory page for RDMA and for sharing data with child processes. The Linux 5.12 kernel introduced "copy on fork" capabilities to address this industry-wide challenge. This feature is present in SLES 15 SP4 and was backported to RHEL 8.6.

### HPE Slingshot Host Software

For the best performance and stability, always use the most recent version of the HPE Slingshot Host Software. Critical fixes for NCCL-based applications were integrated starting with the 2.1.x releases.

### OFI (Libfabric) Backend for NCCL

To enable high-performance RDMA, you must use the OFI Plug-In for Libfabric-to-NCCL. This open-source backend can be downloaded from GitHub at `https://github.com/aws/aws-ofi-nccl`. HPE and NVIDIA have collaborated to ensure this plugin works with Slingshot NICs. Currently, users must build the code from the repository, as HPE does not provide pre-packaged RPMs.

### GPU Driver and User Stack Compatibility

The HPE Slingshot Host Software release notes contain a crucial compatibility matrix for GPU drivers and user-space libraries. For support, HPE will only assist with the specified combinations, as debugging issues with other versions is too complex due to deep interdependencies. [Notes for SHS 13.0.0](https://support.hpe.com/hpesc/public/docDisplay?docId=dp00006840en_us&page=release_notes/support_matrix.html)

### Essential Libfabric Environment Settings

Properly configuring Libfabric environment settings is **mandatory** for running NCCL applications effectively. Incorrect settings can be especially noticeable with the HPE Slingshot NIC due to its extensive hardware offload resources.

| Variable | Recommended Configuration For NCCL | Info |
| :--- | :--- | :--- |
| `FI_MR_CACHE_MONITOR` | `userfaultfd` | Sets the memory cache monitor to detect changes between virtual and physical memory pages. `kdreg2` is another valid option. |
| `FI_CXI_DISABLE_HOST_REGISTER` | `1` | Avoids allocation calls from the provider that may cause deadlocks. |
| `FI_CXI_DEFAULT_CQ_SIZE` | `131072` | Should be increased, especially for large jobs. |
| `FI_CXI_RDZV_PROTO` | `alt_read` | Use the alt_read rendezvous protocol. |
| `FI_CXI_RX_MATCH_MODE` | `hybrid` | It allows the network stack to transition to software matching if hardware resources are exhausted. |
| `FI_CXI_RDZV_EAGER_SIZE` | `0` | Prevents sending data before the receiver is ready. |
| `FI_CXI_DEFAULT_TX_SIZE` | `2048` | Should be set especially for large jobs that are dependent on unexpected rendezvous messaging. |

**Note**: To use the `hybrid` rendezvous protocol, the driver property `rdzv_get_en` must be set to `0`. This can be done system-wide by a privileged user or, ideally, on a per-job basis through a job scheduler like Slurm (`--network=disable_rdzv_get`) or PBS Pro (`--disable-rdzv-get`).

-----

## Environment Settings for NCCL

Several environment variables are required for NVIDIA NCCL to function correctly and achieve good performance.

| Variable | Suggested Value | Info |
| :--- | :--- | :--- |
| `NCCL_CROSS_NIC` | `1` | Has been found to improve performance on large systems. |
| `NCCL_NET_GDR_LEVEL` | `PHB` | Required to enable RDMA between GPUs. |
| `NCCL_SOCKET_IFNAME` | `hsn0,hsn1,hsn2,hsn3` | Limits NCCL's bootstrap and socket communication to a specific interface.  These should match the interfaces available.  |
| `NCCL_NET` | `"AWS Libfabric"` | Ensures that NCCL will terminate if it fails to load the Libfabric plugin, preventing an undesirable fallback to sockets. |

-----

## Installing NCCL and Building `aws-ofi-nccl`

Most CUDA installations include NCCL, so you should use the pre-installed version and build the OFI plugin for Libfabric support. Below is an example script to build the plugin and the `nccl-tests` utility.

```bash
# Set environment variables for dependencies
export CUDA_HOME=/usr/local/cuda
export OFI_HOME=/opt/cray/libfabric/1.15.2.0
export AWS_OFI_PLUGIN_HOME=/path/to/install/aws-ofi-plugin
export HWLOC_PREFIX=`pwd`/hwloc/install

# Build hwloc
echo "==> Building hwloc"
git clone https://github.com/open-mpi/hwloc.git
pushd hwloc
./autogen.sh
./configure --prefix="$HWLOC_PREFIX"
make -j
make install
popd

# Build the OFI Plugin
echo "==> Building aws-ofi-nccl plugin"
git clone https://github.com/aws/aws-ofi-nccl.git && git -C aws-ofi-nccl fetch --tags --quiet && git -C aws-ofi-nccl checkout v1.18.0
pushd aws-ofi-nccl
./autogen.sh
CC=cc CXX=CC ./configure \
  --with-libfabric="$OFI_HOME" \
  --with-cuda="$CUDA_HOME" \
  --with-hwloc="$HWLOC_PREFIX" \
  --prefix="$AWS_OFI_PLUGIN_HOME"
make -j && make install
popd
```

At runtime, ensure the compiled plugin (`libnccl-net.so`) is in your `LD_LIBRARY_PATH`. Many deep learning frameworks include NCCL, so you may be using an older, unsupported version. It's recommended to upgrade or rebuild your packages from source with dynamic linking.

-----

## Troubleshooting Steps

### Low Performance

1.  **Check if the plugin library is in `LD_LIBRARY_PATH`**. If you see the message `No plugin found (libnccl-net.so)`, it means NCCL could not locate the plugin.
2.  **Verify the plugin is loaded**. Set `export NCCL_DEBUG=INFO` and look for the log message `Loaded net plugin AWS Libfabric` for all ranks.
3.  **Confirm network settings**. Check that your environment variables are set as described above.

### Filing a Support Ticket

When filing a ticket with the HPE Slingshot NIC team, please include the following:

  * HPE Slingshot Host Software version 
  * NCCL, MPI, and OFI plugin versions 
  * Application details and documentation 
  * `stdout` and `stderr` logs with `FI_LOG_LEVEL=info` and `FI_LOG_PROV=cxi` enabled 
  * Steps to reproduce the issue 

For NCCL-based applications, also enable `NCCL_DEBUG=info` and ensure the logs show a NCCL version of 2.14 or newer and that the network used is "AWS Libfabric".

Copyright Hewlett Packard Enterprise Development LP
