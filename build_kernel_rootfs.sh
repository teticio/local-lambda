#!/bin/env bash
set -eox pipefail

terraform apply -auto-approve
ip=$(terraform output -json | jq -r '.ip.value')
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null microvm-kernel-x86_64-4.14.config ec2-user@$ip:/home/ec2-user/kernel.config
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@$ip 'bash -s' < ec2_build_kernel_rootfs.sh
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@$ip:/home/ec2-user/rootfs.img .
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@$ip:/home/ec2-user/vmlinux .
terraform destroy -auto-approve
