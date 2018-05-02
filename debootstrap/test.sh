#!/usr/bin/env bash
set -e

mkdir work
cd work

#This is a backup of a previous bootstrapped using --foreign
cp ../deboot.tgz .
sudo tar -xf deboot.tgz
sudo DEBOOTSTRAP_DIR=deboot/debootstrap/ debootstrap --second-stage --second-stage-target $(readlink -f deboot)

#Set locale settings  in chroot
sudo chroot deboot locale-gen "en_US.UTF-8"
sudo chroot deboot  dpkg-reconfigure --frontend=noninteractive locales

#Set apt cache proxy in chroot
echo 'Acquire::http { Proxy "http://127.0.0.1:3142"; };' | sudo tee deboot/etc/apt/apt.conf.d/00aptproxy

# mount the /proc filesystem in the chroot (required for managing processes)
sudo mount -o bind /proc deboot/proc
