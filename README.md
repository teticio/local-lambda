# Local Lambda

The purpose of this repo is to reproduce as closely as possible the conditions of running inisde an AWS Lambda function container to faciliate testing and debugging.

## Install

AWS runs Lambda functions inside a Firecracker VM, so you will need to install [Firecracker](https://github.com/firecracker-microvm/firecracker/tree/main) and Jailer.

In order to extract the Linux kernel and rootfs image from the AMI AWS uses for Lambda, you will need to install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) and run the script `build_kernel_rootfs.sh`. This will spin up an EC2, build the kernel from source, attach a snapshot of the rootfs and create a `rootfs.img`. It will also set the root password to be empty.

## TODO
* Networking
```
ip addr add 172.16.0.2/24 dev eth0
ip link set eth0 up
ip route add default via 172.16.0.1 dev eth0
echo "nameserver 8.8.8.8" > /etc/resolv.conf
```
* Memory size and filesystem size
* Create lambda user with relevant permissions and run lambda handler
