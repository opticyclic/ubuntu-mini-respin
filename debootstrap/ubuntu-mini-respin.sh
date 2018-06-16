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
debootstrap_dir="${work_dir}/debootstrap"

#Patch debootstrap to allow re-running
rm -rf "${debootstrap_dir}"
mkdir -p "${debootstrap_dir}"
cp -r /usr/share/debootstrap/* "${debootstrap_dir}"
cd "${debootstrap_dir}/scripts"
sed -i 's/EXTRACT_DEB_TAR_OPTIONS="$EXTRACT_DEB_TAR_OPTIONS -k"/EXTRACT_DEB_TAR_OPTIONS="$EXTRACT_DEB_TAR_OPTIONS"/g' *
cd -
export EXTRACT_DEB_TAR_OPTIONS="--overwrite"
export DEBOOTSTRAP_DIR="${debootstrap_dir}"

#Make chroot
echo "Chroot dir = ${chroot_dir}"
mkdir -p "${chroot_dir}"
cd "${work_dir}"

#Use a caching proxy to save bandwidth
export http_proxy=http://127.0.0.1:8000

echo "Remove any previous host mounts from chroot"
sudo umount "${chroot_dir}/proc" || true
sudo umount "${chroot_dir}/dev" || true

#Remove nodes that debootstrap created from previous runs
sudo rm -f "${chroot_dir}/dev/null"
sudo rm -f "${chroot_dir}/dev/zero"
sudo rm -f "${chroot_dir}/dev/full"
sudo rm -f "${chroot_dir}/dev/random"
sudo rm -f "${chroot_dir}/dev/urandom"
sudo rm -f "${chroot_dir}/dev/tty"
sudo rm -f "${chroot_dir}/dev/ptmx"
#Clear previous file handles
sudo unlink "${chroot_dir}/dev/fd"
sudo unlink "${chroot_dir}/dev/stdin"
sudo unlink "${chroot_dir}/dev/stdout"
sudo unlink "${chroot_dir}/dev/stderr"

#Remove previous log file (-f ignores the error if it doesn't exist)
sudo rm -f "${chroot_dir}/debootstrap/debootstrap.log"

if ! sudo -E debootstrap --verbose --arch=${ARCH} ${RELEASE} ${chroot_dir}; then
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

#Using pre-built sources as we don't know what the host has
sudo cp "${script_dir}/etc/apt/sources.list" ${chroot_dir}/etc/apt/sources.list

echo "Removing host mounts from chroot"
sudo umount "${chroot_dir}/proc"
sudo umount "${chroot_dir}/dev"

echo "Finished"
