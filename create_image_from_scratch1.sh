#!/bin/bash

version=3.22.0
mirror=https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud
chroot_dir=/mnt/alpine/
arch=aarch64
date=$(date +%F)
alpine_image=generic_alpine-${version}-${arch}-uefi-cloudinit-r0
image_name=alpine-raspberrypi-5-${date}.img
image_size=2048

# create image
dd if=/dev/zero of=${image} bs=512 count=$(("${image_size}" * 1024 * 1024 / 512))
losetup -fP ${image_name}
parted /dev/loop0 --script mklabel msdos mkpart primary fat32 1MiB 600MiB mkpart primary ext4 600MiB  100%

# format partitions
mkfs.vfat -F 32 /dev/loop0p1 
mkfs.ext4 /dev/loop0p2

# mount image to chroot
#losetup -fP ${image_name}
mount /dev/loop0p2 ${chroot_dir}
mkdir ${chroot_dir}/boot
mount /dev/loop0p1 ${chroot_dir}/boot

# download cloud image
wget -c ${mirror}/${alpine_image}.qcow2
qemu-img convert -f qcow2 -O raw ${alpine_image}.qcow2 ${alpine_image}.img -p
losetup -fP ${alpine_image}.img
mount /dev/loop1p2 /mnt/cloudimg
mount /dev/loop1p1 /mnt/cloudimg/boot

# copy data from cloudimg to alpineimg
rsync -av /mnt/cloudimg/* /mnt/alpine/

# umount image
umount /mnt/cloudimg/boot
umount /mnt/cloudimg
losetup -d /dev/loop1

# copy qemu-arm-static
cp /usr/bin/qemu-aarch64-static ${chroot_dir}/usr/bin/

# copy nameservers
if [ ! -d ${chroot_dir}/etc ];
then
mkdir ${chroot_dir}/etc
echo "nameserver 4.2.2.1" > ${chroot_dir}/etc/resolv.conf
echo "nameserver 4.2.2.2" >> ${chroot_dir}/etc/resolv.conf
else
echo "nameserver 4.2.2.1" > ${chroot_dir}/etc/resolv.conf
echo "nameserver 4.2.2.2" >> ${chroot_dir}/etc/resolv.conf
fi

# mount proc,dev,sys

if [ ! -d ${chroot_dir}/dev ];
then 
mkdir ${chroot_dir}/dev
mount -o bind /dev ${chroot_dir}/dev
else
mount -o bind /dev ${chroot_dir}/dev
fi 

if [ ! -d ${chroot_dir}/proc ];
then
mkdir ${chroot_dir}/proc
mount -t proc none ${chroot_dir}/proc
else
mount -t proc none ${chroot_dir}/proc
fi

if [ ! -d ${chroot_dir}/sys ];
then
mkdir ${chroot_dir}/sys
mount -o bind /sys ${chroot_dir}/sys
else
mount -o bind /sys ${chroot_dir}/sys
fi
