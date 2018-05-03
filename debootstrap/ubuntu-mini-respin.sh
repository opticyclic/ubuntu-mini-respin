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

#Make chroot
echo "Chroot dir = ${chroot_dir}"
mkdir -p "${chroot_dir}"
cd "${work_dir}"

sudo debootstrap --verbose --arch=${ARCH} ${RELEASE} ${chroot_dir}
if [ "$?" -ne "0" ]; then
  echo "debootstrap failed."
  echo "See ${chroot_dir}/debootstrap/debootstrap.log for more information."
  exit 1
fi

echo "debootstrap succeeded"
