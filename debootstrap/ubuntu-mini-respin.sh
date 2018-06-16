#!/usr/bin/env bash
set -e

#The purpose of this script is to use debootstrap to create a minimal
#Ubuntu distribution that can be used for respins
#From https://help.ubuntu.com/community/LiveCDCustomizationFromScratch
#sudo apt install rsync debootstrap syslinux squashfs-tools genisoimage mkisofs

ARCH=amd64
RELEASE=xenial

script_dir="$(dirname $(readlink -f "$0"))"
work_dir="${script_dir}/build"
chroot_dir="${work_dir}/${RELEASE}"

echo "Clean chroot from any previous runs"
sudo umount "${chroot_dir}/proc" || true
sudo umount "${chroot_dir}/dev" || true
sudo rm -rf "${work_dir}"

#Make chroot
echo "Chroot dir = ${chroot_dir}"
mkdir -p "${chroot_dir}"
cd "${work_dir}"

#Use a caching proxy to save bandwidth
export http_proxy=http://127.0.0.1:8000

if ! sudo debootstrap --verbose --arch=${ARCH} ${RELEASE} ${chroot_dir}; then
  echo "debootstrap failed."
  echo "See ${chroot_dir}/debootstrap/debootstrap.log for more information."
  exit 1
fi

echo "debootstrap succeeded"

#Mount the /proc filesystem in the chroot (otherwise you can't run processes in it)
sudo mount -o bind /proc "${chroot_dir}/proc"

#Mount /dev in the chroot so that grub-probe can succeed
sudo mount -o bind /dev "${chroot_dir}/dev"

#Copy the host DNS details to enable internet access within the chroot
sudo cp /etc/resolv.conf ${chroot_dir}/etc/resolv.conf

echo "Removing host mounts from chroot"
sudo umount "${chroot_dir}/proc"
sudo umount "${chroot_dir}/dev"

echo "Finished"
