#!/usr/bin/env bash
set -eox pipefail

# Check for EC2 instance
if ! curl -s http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    echo "Must be run on an EC2 instance. Exiting."
    exit 1
fi

# build kernel from source
sudo yum update -y
sudo yum groupinstall -y "Development Tools"
sudo yum install -y ncurses-devel bc openssl-devel elfutils-libelf-devel flex bison patch
yumdownloader --source kernel
mkdir kernel
cd kernel
rpm2cpio ../kernel-*.rpm | cpio -idmv
rm ../kernel-*.rpm
for file in linux-*.tar; do
    tar -xvf "$file"
done
cd $(ls -d linux-* | head -n 1)
for patchfile in ../*.patch; do
    patch -p1 < "$patchfile"
done
cp ../../kernel.config .config
yes "" | make oldconfig || true
make -j$(nproc)
mv vmlinux ../..
cd ../..
rm -rf kernel

# build rootfs
sudo kpartx -av /dev/sdf
sleep 1
sudo dd if=/dev/mapper/sdf1 of=rootfs.img bs=512
