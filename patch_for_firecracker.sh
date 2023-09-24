#!/usr/bin/env bash

mkdir rootfs
sudo mount rootfs.img rootfs
# set root password to empty and set up eth0
sudo chroot rootfs/ /bin/bash <<EOF
passwd -d root
sed -i 's/BOOTPROTO=dhcp/BOOTPROTO=static/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '/^DHCP/d' /etc/sysconfig/network-scripts/ifcfg-eth0
echo -e 'IPADDR=172.16.0.2\nNETMASK=255.255.255.0\nGATEWAY=172.16.0.1\nIPV6INIT=no\nARPCHECK=no' >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "nameserver 8.8.8.8" > /etc/resolv.conf
EOF
sudo umount rootfs
rmdir rootfs
