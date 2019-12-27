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
image_dir="${work_dir}/image/${RELEASE}"
iso_path="${work_dir}/ubuntu-remix-${RELEASE}.iso"

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

#Make the image directory and the 3 required subdirectories.
mkdir -p "${image_dir}/casper/vmlinuz"
mkdir -p "${image_dir}/isolinux"
mkdir -p "${image_dir}/install"

#echo "Copy kernel and initrd from chroot to image"
#How is the kernel supposed to get into the chroot?a
sudo cp ${chroot_dir}/boot/vmlinuz-*-generic "${image_dir}/casper/vmlinuz"
sudo cp ${chroot_dir}/boot/initrd.img-*-generic "${image_dir}/casper/initrd.lz"

#Copy isolinux and memtest binaries from host.
#Location has changed since the wiki was written
#Sometimes in /usr/lib/syslinux/isolinux.bin
#Sometimes in /usr/lib/ISOLINUX/isolinux.bin
isolinux_bin=$(find /usr/lib/ -name "isolinux.bin")
cp "${isolinux_bin}" "${image_dir}/isolinux"
cp /boot/memtest86+.bin "${image_dir}/install/memtest"

#Give some boot-time instructions to the user
#
#TODO: Create a splash image in the file below
#To create the splash.rle file, create an image 480 pixels wide.
#Convert it to 15 colours, indexed (perhaps using GIMP) and "Save As" to change the ending to .bmp which converts the image to a bitmap format.
#Then install the "netpbm" package and run
#bmptoppm splash.bmp > splash.ppm
#ppmtolss16 '#ffffff=7' < splash.ppm > splash.rle
#
#cp isolinux.txt "${image_dir}/isolinux"

#Provide configuration settings for the boot-loader.
#TODO Verify this as it is a sample
#cp isolinux.cfg "${image_dir}/isolinux"

#Create a manifest
sudo chroot ${chroot_dir} dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${image_dir}/casper/filesystem.manifest"
sudo cp -v "${image_dir}/casper/filesystem.manifest" "${image_dir}/casper/filesystem.manifest-desktop"

log "Remove installer packages from the base system now we have created the installer"
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for i in $REMOVE
do
  sudo sed -i "/${i}/d" "${image_dir}/casper/filesystem.manifest-desktop"
done

log "Compress the chroot dir to a file in the image dir"
sudo mksquashfs ${chroot_dir} "${image_dir}/casper/filesystem.squashfs"

#Then write the filesystem.size file, which is needed by the installer
printf $(sudo du -sx --block-size=1 ${chroot_dir} | cut -f1) > "${image_dir}/casper/filesystem.size"

#This is needed to make the USB Creator work with this custom iso image.
touch "${image_dir}/ubuntu"
mkdir "${image_dir}/.disk"
cd "${image_dir}/.disk"
touch base_installable
echo "full_cd/single" > cd_type
#TODO: Make this version number a variable
echo "Ubuntu Remix 16.04" > info
#TODO: Make this URL a variable
echo "http//your-release-notes-url.com" > release_notes_url

cd "${work_dir}"
#Calculate MD5
cd "${image_dir}"
sudo find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt

log "Create iso from the image directory"
volume_id=ubuntu-remix
sudo mkisofs -r -V "${volume_id}" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "${iso_path}" .

log "Change owner of iso to user"
cd "${script_dir}"
user_group=$(stat -c "%U:%G" .)
sudo chown "${user_group}" "${iso_path}"

log "Finished"
