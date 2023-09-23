#!/bin/env bash

TAP_DEV="tap0"
TAP_IP="172.16.0.1"
MASK_SHORT="/24"
ETH_DEV="enp4s0"

# Setup network interface
sudo ip link del "$TAP_DEV" 2> /dev/null || true
sudo ip tuntap add dev "$TAP_DEV" mode tap
sudo ip addr add "${TAP_IP}${MASK_SHORT}" dev "$TAP_DEV"
sudo ip link set dev "$TAP_DEV" up

# Enable ip forwarding
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

# Set up microVM internet access
sudo iptables -t nat -D POSTROUTING -o "$ETH_DEV" -j MASQUERADE || true
sudo iptables -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT \
    || true
sudo iptables -D FORWARD -i "$TAP_DEV" -o "$ETH_DEV" -j ACCEPT || true
sudo iptables -t nat -A POSTROUTING -o "$ETH_DEV" -j MASQUERADE
sudo iptables -I FORWARD 1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I FORWARD 1 -i "$TAP_DEV" -o "$ETH_DEV" -j ACCEPT

API_SOCKET="/srv/jailer/firecracker/test/root/run/firecracker.socket"

# Create log file
touch firecracker.log

# Set log file
sudo curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"log_path\": \"firecracker.log\",
        \"level\": \"Debug\",
        \"show_level\": true,
        \"show_log_origin\": true
    }" \
    "http://localhost/logger"

KERNEL_BOOT_ARGS="console=ttyS0 reboot=k panic=1 pci=off fastboot"

ARCH=$(uname -m)

if [ ${ARCH} = "aarch64" ]; then
    KERNEL_BOOT_ARGS="keep_bootcon ${KERNEL_BOOT_ARGS}"
fi

# Set boot source
sudo curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"kernel_image_path\": \"vmlinux\",
        \"boot_args\": \"${KERNEL_BOOT_ARGS}\"
    }" \
    "http://localhost/boot-source"

# Set rootfs
sudo curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"drive_id\": \"rootfs\",
        \"path_on_host\": \"rootfs.img\",
        \"is_root_device\": true,
        \"is_read_only\": false
    }" \
    "http://localhost/drives/rootfs"


# Set rootfs
sudo curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"mem_size_mib\": 512,
        \"vcpu_count\": 1
    }" \
    "http://localhost/machine-config"

# The IP address of a guest is derived from its MAC address with
# `fcnet-setup.sh`, this has been pre-configured in the guest rootfs. It is
# important that `TAP_IP` and `FC_MAC` match this.
FC_MAC="9e:34:70:47:0b:a6"

# # Set network interface
sudo curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"iface_id\": \"ext0\",
        \"guest_mac\": \"$FC_MAC\",
        \"host_dev_name\": \"$TAP_DEV\"
    }" \
    "http://localhost/network-interfaces/ext0"

# API requests are handled asynchronously, it is important the configuration is
# set, before `InstanceStart`.
sleep 0.015s

# Start microVM
sudo curl -X PUT --unix-socket "${API_SOCKET}" \
    --data "{
        \"action_type\": \"InstanceStart\"
    }" \
    "http://localhost/actions"
