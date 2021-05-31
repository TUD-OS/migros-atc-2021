# migros-atc-2021

Repository linking to the software artifacts used for the MigrOS ATC 2021 paper

# Contents

The description of the code base:

1. rxe-fix-races

Git module rxe-fix-races contains the sources of the Linux kernel with a fixed SoftRoCE driver.

2. linux-dump

Git module linux-dump contains the sources of the Linux kernel with a migratable SoftRoCE driver.

3. CRIU source

Git module criu contains the sources of ibverbs-enabled CRIU

3. RDMA-core (workaround)

Git module rdma-core-workaround contains the RDMA-core repository with a small
workaround to use rxe user-device driver first. We used this version inside the
container, because in certain situations, the libibverbs was not able to use
SoftRoCE device driver for SoftRoCE device. Instead, it was picking mlx4
user-level device driver.

4. RDMA-core (host)

Git module rdma-core contains the RDMA-core repository enabled for
checkpointing/restarting of libibverbs objects. The repo is to be used by CRIU.

5. Perftest tools

Git module perftest contains the modified version of the perftest benchmark

6. konk

Our container runtime.

7. Docker

Dockerfile used to build the docker image for testing out container migration.
We reuse the same docker image for our container runtime, after converting it
into OCI-compatible archive.

Docker-migration.md is a description of a workflow to run live migration with docker.

