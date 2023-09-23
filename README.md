# Local Lambda

The purpose of this repo is to reproduce as closely as possible the conditions of running inside an AWS Lambda function container to facilitate testing and debugging.

## Install

AWS runs Lambda functions inside a Firecracker VM, so you will need to install [Firecracker](https://github.com/firecracker-microvm/firecracker/tree/main) and Jailer.

In order to extract the Linux kernel and rootfs image from the AMI AWS uses for Lambda, you will need to install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) and run the script `build_kernel_rootfs.sh`. This will spin up an EC2, build the kernel from source, attach a snapshot of the rootfs and create a `rootfs.img`. It will also set the root password to be empty and setup the `eth0` to point to the IP gateway `172.16.0.1` with static IP address `172.16.0.2`.

## Run

Start up Firecracker with the following command:

```bash
./start_firecracker.sh
```

then, in another terminal, run the following command to start the VM:

```bash
./start_vm.sh
```

In the output from the first shell you will notice various attempts to get an API token from the magic 169.254.169.254 IP address which will, of course, fail as we are not running inside an AWS environment.

## TODO
* Create lambda user with relevant permissions and run lambda handler
