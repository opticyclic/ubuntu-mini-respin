#!/usr/bin/env bash
set -e

#The purpose of this script is to use debootstrap to create a minimal
#Ubuntu distribution that can be used for respins
#From https://help.ubuntu.com/community/LiveCDCustomizationFromScratch
#sudo apt install rsync debootstrap syslinux squashfs-tools genisoimage mkisofs

function log() {
    echo "## $1"
}

ARCH=amd64
RELEASE=xenial

script_dir="$(dirname $(readlink -f "$0"))"
work_dir="${script_dir}/build"
chroot_dir="${work_dir}/${RELEASE}"

log "Clean chroot from any previous runs"
sudo umount "${chroot_dir}/proc" || true
sudo umount "${chroot_dir}/dev" || true
sudo umount "${chroot_dir}/sys" || true
sudo rm -rf "${work_dir}"

#Make chroot
log "Chroot dir = ${chroot_dir}"
mkdir -p "${chroot_dir}"
cd "${work_dir}"

#Use a caching proxy to save bandwidth
export http_proxy=http://127.0.0.1:8000

if ! sudo debootstrap --verbose --arch=${ARCH} --components=main,restricted,universe --variant=minbase ${RELEASE} ${chroot_dir}; then
  log "debootstrap failed."
  log "See ${chroot_dir}/debootstrap/debootstrap.log for more information."
  exit 1
fi

log "debootstrap succeeded"

#Mount the /proc filesystem in the chroot (otherwise you can't run processes in it)
sudo mount -o bind /proc "${chroot_dir}/proc"

#Mount /dev in the chroot so that grub-probe can succeed
sudo mount -o bind /dev "${chroot_dir}/dev"

#Mount /sys in the chroot so that partitions can be listed for grub
sudo mount -o bind /sys "${chroot_dir}/sys"

#Copy the host DNS details to enable internet access within the chroot
sudo cp /etc/resolv.conf ${chroot_dir}/etc/resolv.conf

log "Create an install script to run in the chroot"
CHROOT_SCRIPT=/tmp/chroot_script.sh
cat > $CHROOT_SCRIPT <<EOF
#!/bin/bash

function log() {
    echo "#### \$1"
}

#Install packages needed for Live System
apt-get update
locale-gen "en_US.UTF-8"
dpkg-reconfigure --frontend=noninteractive locales

log "Installing ubuntu base"
apt-get install --yes ubuntu-standard

log "Installing kernel"
DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install linux-generic

#https://answers.launchpad.net/ubuntu-mini-remix/+faq/33
log "Installing live packages"
apt-get install --yes casper lupin-casper discover laptop-detect os-prober

#Add Ubiquity front end
log "Installing ubiquity"
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" ubiquity-frontend-gtk

log "Cleanup the chroot"
apt-get clean
rm /var/lib/dbus/machine-id
rm -rf /tmp/*
rm /etc/resolv.conf

EOF

chmod +x $CHROOT_SCRIPT
sudo mv $CHROOT_SCRIPT ${chroot_dir}/tmp/

log "Run the install script in chroot"
sudo chroot ${chroot_dir} $CHROOT_SCRIPT

log "Removing host mounts from chroot"
sudo umount "${chroot_dir}/proc"
sudo umount "${chroot_dir}/dev"
sudo umount "${chroot_dir}/sys"

log "Finished"
