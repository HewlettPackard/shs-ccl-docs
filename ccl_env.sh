# SPDX-FileCopyrightText: Copyright Hewlett Packard Enterprise Development LP
# SPDX-License-Identifier: MIT

# Source this file to include recommended NCCL or RCCL environment variables.
#
# RCCL, NCCL, aws-ofi-nccl  and fabric environment variables for all_reduce_perf
# Note: When running with slurm, the flag --network=disable_rdzv_get is required
# and must be added to the srun command.  When running with PBS, the flag
# --disable_rdzv_get is required.

export HSA_FORCE_FINE_GRAIN_PCIE=1
export FI_MR_CACHE_MONITOR=userfaultfd
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_CXI_DEFAULT_CQ_SIZE=131072
export FI_CXI_RDZV_PROTO=alt_read
export FI_CXI_RDZV_EAGER_SIZE=0
export FI_CXI_DEFAULT_TX_SIZE=2048
export NCCL_CROSS_NIC=1
export NCCL_NET_GDR_LEVEL=PHB
export NCCL_SOCKET_IFNAME=hsn0,hsn1,hsn2,hsn3
export NCCL_NET="AWS Libfabric"
export FI_CXI_RX_MATCH_MODE=hybrid
