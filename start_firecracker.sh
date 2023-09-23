#!/bin/env bash

sudo rm -rf /srv/jailer/*
sudo mkdir -p /srv/jailer/firecracker/test/root
sudo touch /srv/jailer/firecracker/test/root/firecracker.log
sudo chown nvidia-persistenced:users /srv/jailer/firecracker/test/root/firecracker.log
sudo cp vmlinux /srv/jailer/firecracker/test/root/vmlinux
sudo chown nvidia-persistenced:users /srv/jailer/firecracker/test/root/vmlinux
sudo cp rootfs.img /srv/jailer/firecracker/test/root/rootfs.img
sudo chown nvidia-persistenced:users /srv/jailer/firecracker/test/root/rootfs.img

sudo jailer --id test \
--cgroup cpuset.mems=0 --cgroup cpuset.cpus=$(cat /sys/devices/system/node/node0/cpulist) \
--cgroup-version 2 \
--exec-file /usr/local/bin/firecracker --uid 123 --gid 100
