#!/usr/bin/env bash

mkdir rootfs
sudo mount rootfs.img rootfs
sudo cp -r files_debootstrap/* rootfs/
sudo umount rootfs
rmdir rootfs
