#!/bin/bash
 
chroot_dir=/mnt/alpine/
date=$(date +%F)
user=skywalker
pass=vidalinux
desktop=lxqt
rpi5=true

# remove packages
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && \
apk del cloud-init-openrc cloud-init linux-virt cloud-init-pyc grub grub-efi"

# update installed packages
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && \
apk upgrade"

# install tools
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && \
apk add nano git wget curl rsync networkmanager-openrc parted multipath-tools xfsprogs \
lsof git sudo fakeroot screen wpa_supplicant-openrc ntfs-3g ntfs-3g-progs exfat-utils \
p7zip net-tools htop usbutils chrony-openrc openvpn-openrc netcat-openbsd shadow \
findmnt newt lsblk"

# setup desktop
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && \ 
setup-desktop ${desktop}"

# fix audio on desktop
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && \
apk add pulseaudio"

# setup boot kernel
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && \
apk add linux-rpi raspberrypi-utils raspberrypi-bootloader"

# add service to boot
#chroot ${chroot_dir} /bin/ash -c "source /etc/profile && rc-update add lightdm default"
#chroot ${chroot_dir} /bin/ash -c "source /etc/profile && rc-update add NetworkManager default"
#chroot ${chroot_dir} /bin/ash -c "source /etc/profile && rc-update add sshd default"
#chroot ${chroot_dir} /bin/ash -c "source /etc/profile && rc-update add chronyd default"

# fix fstab
cat > ${chroot_dir}/etc/fstab << EOF
/dev/mmcblk0p1  /boot   vfat    defaults        0       0
/dev/mmcblk0p2  /       ext4    defaults        0       0
EOF

# set root password
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && echo "root:${pass}" | chpasswd"

# install expand-sd script
cp ./scripts/expand-sd ${chroot_dir}/usr/local/bin/
chmod +x ${chroot_dir}/usr/local/bin/expand-sd

# create user
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && userdel -r alpine"
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && useradd -m ${user}"
chroot ${chroot_dir} /bin/ash -c "source /etc/profile && echo "${user}:${pass}" | chpasswd"
echo "${user} ALL=(ALL:ALL) ALL" > ${chroot_dir}/etc/sudoers.d/${user}

# fix config.txt
cat >> ${chroot_dir}/boot/config.txt << EOF

# Enable DRM VC4 V3D driver
dtoverlay=vc4-kms-v3d
max_framebuffers=2

# audio jack
dtparam=audio=on
hdmi_ignore_edid_audio=1
audio_pwm_mode=2

enable_uart=1
EOF

# fix xorg.conf
if [ ${rpi5} == true ];
then
cat > ${chroot_dir}/etc/X11/xorg.conf << EOF
Section "OutputClass"
  Identifier "vc4"
  MatchDriver "vc4"
  Driver "modesetting"
  Option "PrimaryGPU" "true"
EndSection
EOF
fi

# create cmdline.txt
cat > ${chroot_dir}/boot/cmdline.txt << EOF
root=/dev/mmcblk0p2 rw rootwait console=serial0,115200 console=tty1 fsck.repair=yes
EOF

# umount partitions
umount ${chroot_dir}/dev
umount ${chroot_dir}/proc
umount ${chroot_dir}/sys
umount ${chroot_dir}/boot
umount ${chroot_dir}
losetup -d /dev/loop0
