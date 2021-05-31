# Container migration with Docker

To test out container migration, instead of using CR-X, we provide instructions
for using Docker. You would need two nodes connected in a network. Both the
nodes need to configure SoftRoCE. We assume that the SoftRoCE device is `rxe0`
with a minor number `192` (limitation of the PoC, not a fundamental limitation).

  1. Create the image
  
  Build the image from the proposed Dockerfile
  
  ```
  docker build -t docker-repo/perftest .
  ```
  
  To distribute the image among multiple nodes, one of the ways is to push it to
  docker hub:
  
  ```
  docker push docker-repo/perftest:latest
  ```
  
  We do not describe how to register on docker hub.
  
  2. Configure docker
  
  This step applies to both nodes. We do not describe docker installation
  procedure.
  
  To enable checkpoint/restart in Docker create file `/etc/docker/daemon.json`
  with following contents:
  
  ```
  {
     "experimental": true
  }
  ```
  
  Restart the daemons
  
  3. Configure swarm
  
  Create an overlay network.
  
  ```
  docker network create -d overlay --attachable rdma-net --subnet 10.0.1.0/24
  ``` 
  
  One of the ways is to use "docker swarm". Run the following command on one of
  the nodes designated as manager.
  
  ```
  docker swarm init
  ```
  
  This command will print a command to run on worker nodes:
  
  ```
  docker swarm join --token SWMTKN-<...> <IP>:<PORT>
  ```
  
  Run the command that was printed on another node
  
  3. Start the server side
  
  The application runs a bidirectional bandwidth benchmark that consists of
  server and client applications. The server must be started before the client.
  
  For our setup, we create two containers: `cont-static` and `cont-moving`. We
  run the server in `cont-moving`, and the client in the `cont-static`.
  
  Following is the script for running the server.
  
  ```
  #!/bin/bash

  docker rm --force cont-moving

  docker create --name cont-moving --network rdma-net --ip 10.0.1.7 \
     --security-opt seccomp:unconfined --ulimit memlock=1073741824 \
     --cap-add=ALL --memory=1g --kernel-memory=1G --device /dev/infiniband/ \
     docker-repo/perftest:latest ib_send_bw -d rxe0 -n 100000 -b

  echo 64 > /proc/sys/net/rdma_rxe/last_qpn
  echo 64 > /proc/sys/net/rdma_rxe/last_mrn
  docker start cont-moving
  ```
  
  This script first removes the existing instance of cont-moving.
  
  The second line creates the container for image "docker-repo/perftest". The
  name should be the same as in the first step of the instruction. The command
  should provide the overlay network name, resource limitations, access to the
  InfiniBand devices, and security privileges.
  
  We should specify the IP address explicitly for the migration experiment.
  
  Next two command set the initial number of the QP and MR ids. These commands
  are also important for the migration experiment. We need to make sure that
  client and server use different initial numbers to avoid conflicts for the ids
  (see paper for the details).
  
  Finally, we start the container.
  
  We use bidirectional test, because we need to make sure that QPs on both ends
  are in the RTS state. There is a limitation of our PoC, that we do not send
  resume message from RTR state. This is not a fundamental limitation.
  
  4. Start the client side
  
  The client side uses very similar parameters as the server side.
  
  ```
  #!/bin/bash

  docker rm --force cont-moving
  docker rm --force cont-static
  
  echo 16 > /proc/sys/net/rdma_rxe/last_qpn 
  echo 16 > /proc/sys/net/rdma_rxe/last_mrn
  docker run --rm --name cont-static --network rdma-net --ip 10.0.1.3 \
     --security-opt seccomp:unconfined --ulimit memlock=1073741824 \
     --cap-add=ALL --memory=1g --kernel-memory=1G --device /dev/infiniband/ \
     docker-repo/perftest:latest ib_send_bw -d rxe0 -n 100000 10.0.1.7 -b
  ```
  
  The main difference to the server side command is a different IP address of
  the container and the specification of the IP address of the server.
  
  Client and server run on different nodes.
  
  If the client and server are left to run, the benchmark must finish normally.

  4. Migrate the server
  
  For this experiment we show how to migrate the server.
  
  Following script must run on the client side.

  ```
  #!/bin/bash

  docker rm cont-moving

  ssh server-node docker checkpoint create cont-moving ckpt1

  docker create --name cont-moving --network rdma-net --ip 10.0.1.7 \
     --security-opt seccomp:unconfined --ulimit memlock=1073741824 \
     --cap-add=ALL --memory=1g --kernel-memory=1G --device /dev/infiniband/ \
     docker-repo/perftest:latest ib_send_bw -d rxe0 -n 100000

  SRC_ID=$(ssh server-node docker inspect --format="{{.Id}}" cont-moving)
  DEST_ID=$(docker inspect --format="{{.Id}}" cont-moving)
  CONTAINERS=/var/lib/docker/containers/

  echo 64 > /proc/sys/net/rdma_rxe/last_qpn 
  echo 64 > /proc/sys/net/rdma_rxe/last_mrn
  scp -r server-node:$CONTAINERS/$SRC_ID/checkpoints/ckpt1 $CONTAINERS/$DEST_ID/checkpoints/

  ssh server-node docker rm cont-moving

  docker start cont-moving --checkpoint ckpt1
  ```
  
  First, we remove an old instance of the server container.
  
  Next, we request the docker daemon on the client side to create a checkpoint.
  
  Then, we create the container with the server on the local node.
  
  Now, we need to copy the checkpoint from the remote node to the local node.
  
  Before restarting the container on the local node, we remove the container on
  the remote node to avoid IP address collision.
  
  Finally, we restart the container with the server on the local node.
  
  If everything goes well, the benchmark will finish after several seconds.
