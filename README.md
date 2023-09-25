# Local Lambda

The purpose of this repo is to reproduce as closely as possible the conditions of running inside an AWS Lambda function container to facilitate testing and debugging.

## Install

AWS runs Lambda functions inside a Firecracker VM, so you will need to install [Firecracker](https://github.com/firecracker-microvm/firecracker/tree/main). As we are going to be using `firecracker-containerd`, the easiest way to install everything we need (providing you already have [Docker](https://docs.docker.com/engine/install/) installed) is by running the following commands from the [quick start guide](https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md):

```bash
git clone https://github.com/firecracker-microvm/firecracker-containerd.git
cd firecracker-containerd
sg docker -c 'make all image firecracker'
sudo make install install-firecracker demo-network
sudo install -D -o root -g root -m755 -t /usr/local/bin ./_submodules/firecracker/build/cargo_target/x86_64-unknown-linux-musl/release/jailer
```

You may need to add the following lines to `/etc/cni/conf.d/fcnet.conflist` and remove the reference to `\etc\resolv.conf` if your host is using a systemd resolver in order for DNS lookup to work:

```json
      "dns": {
        "nameservers": [ "8.8.8.8" ]
      }
```

In order to extract the Linux kernel and rootfs image from the AMI AWS uses for Lambda, you will need to install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) and run the script `build_kernel_rootfs.sh`. This will spin up an EC2, build the kernel from source, attach a snapshot of the rootfs and create a `rootfs.img`. It will also set the root password to be empty and setup the `eth0` to point to the IP gateway `172.16.0.1` with static IP address `172.16.0.2`.

## Run in Firecracker

Patch the rootfs image by running:

```bash
./patch_for_firecracker.sh
```

Start up Firecracker with the following command:

```bash
./start_firecracker.sh
```

then, in another terminal, run the following command to start the VM:

```bash
./start_vm.sh
```

In the output from the first shell you will notice various attempts to get an API token from the magic 169.254.169.254 IP address which will, of course, fail as we are not running inside an AWS environment. After a few minutes, the login prompt will appear and you will be able to login as `root` with no password.

To clean up the runtime environment, run the following command:

```bash
sudo rm -rf /srv/jailer/*
```

## Run in firecracker-containerd

If you want to run a Lambda function, then you will need to run the VM in `firtecracker-containerd`. For this you need to use a the rootfs image that was built for `firecracker-containerd`.

```
bash
cp ../firecracker-containerd/tools/image-builder/rootfs.img default-rootfs.img
```

and initialize the containerd environment with

```bash
./init_firecracker_containerd.sh
```

This will create a 10G thinpool in `/var/lib/firecracker-containerd/snapshotter/devmapper`. You may want to adjust the sizes of the thinpool and the base image. Then start up `firecracker-containerd` with the following command:

```bash
sudo firecracker-containerd --config /etc/firecracker-containerd/config.toml
```

As a test you can run

```bash
sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock \
     image pull \
     --snapshotter devmapper \
     docker.io/library/debian:latest

sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock \
     run \
     --snapshotter devmapper \
     --runtime aws.firecracker \
     --rm --tty --net-host \
     docker.io/library/debian:latest \
     test     
```

To remove the image

```bash
sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock \
     image remove docker.io/library/debian:latest
```

To run a lambda function, we first have to build the image with Docker, save it locally and import it into `firecracker-containerd`:

```bash
docker build . -t test_lambda
docker save -o test_lambda.tar test_lambda
sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock \
     images import test_lambda.tar \
     --snapshotter devmapper
```

Then we can run the lambda function with

```bash
sudo firecracker-ctr --address /run/firecracker-containerd/containerd.sock \
     run \
     --snapshotter devmapper \
     --runtime aws.firecracker \
     --rm --tty --net-host \
     docker.io/library/test_lambda:latest \
     test
```

To invoke the Lambda function run this on the host:

```bash
ip=$(sudo cat /var/lib/cni/networks/fcnet/last_reserved_ip.0)
curl -XPOST "http://$ip:8080/2015-03-31/functions/function/invocations" -d '{}'
```

To clean up, make sure you have deleted all the containers and images and then remove the thinpool and runtime with

```bash
sudo rm -rf /var/lib/firecracker-containerd/snapshotter/devmapper
sudo rm -rf /var/lib/firecracker-containerd/runtime
```

You may also want to deactivate the thinpool

```bash
sudo dmsetup remove fc-dev-thinpool
```

and remove the loopback devices

```bash
sudo losetup | grep firecracker
```

with

```bash
sudo losetup -d /dev/loopX
```

## TODO
* jailer for firecracker-containerd
* read only filesystem except for /tmp
