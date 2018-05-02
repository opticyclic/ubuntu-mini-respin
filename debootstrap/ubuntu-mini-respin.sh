#!/usr/bin/env bash
set -e

#The purpose of this script is to use debootstrap to create a minimal
#Ubuntu distribution that can be used for respins
#From https://help.ubuntu.com/community/LiveCDCustomizationFromScratch
#sudo apt install rsync debootstrap syslinux squashfs-tools genisoimage mkisofs

script_dir="$(dirname $(readlink -f "$0"))"
iso_path="${script_dir}"/ubuntu-remix.iso
work_dir="${script_dir}/work"
chroot_dir="${work_dir}/deboot"
image_dir="${work_dir}/image"

ARCH=amd64
RELEASE=artful

#Make chroot
echo "Chroot dir = ${chroot_dir}"
mkdir -p "${chroot_dir}"
cd "${work_dir}"

#--make-tarball boot.tar.gz does this (tarball must be .tar or .tgz)
#cd bootstrap
#sudo tar czf - var/lib/apt var/cache/apt >../boot.tgz
#
#unpack with full path
#sudo debootstrap --verbose --arch=amd64 --unpack-tarball /tmp/boot.tgz zesty chroot 
#
#or split stages
#sudo debootstrap --foreign zesty deboot
#sudo tar -czf deboot.tgz deboot
#cp ../deboot.tgz .
#sudo tar -xf deboot.tgz
#sudo DEBOOTSTRAP_DIR=deboot/debootstrap/ debootstrap --second-stage --second-stage-target $(readlink -f "${chroot_dir}")

sudo debootstrap --verbose --arch=${ARCH} ${RELEASE} ${chroot_dir}
#sudo debootstrap --verbose --arch=amd64 zesty chroot http://localhost:3142
if [ "$?" -ne "0" ]; then
  echo "debootstrap failed."
  echo "See ${chroot_dir}/debootstrap/debootstrap.log for more information."
  exit 1
fi

echo "debootstrap succeeded"
exit 1
#Bind /dev to the chroot so that grub-probe can succeed
#sudo mount --bind /dev "${chroot_dir}/dev"

# mount the /proc filesystem in the chroot (required for managing processes)
sudo mount -o bind /proc "${chroot_dir}/proc"

# sudo mount -o bind /sys "${chroot_dir}/sys"
# 
# sudo chroot deboot

#Copy system files for internet
#
#TODO: Remove after??
#sudo cp /etc/hosts ${chroot_dir}/etc/hosts
#sudo cp /etc/resolv.conf ${chroot_dir}/etc/resolv.conf

#Using pre-built sources as we don't know what the host has
sudo cp "${script_dir}/etc/apt/sources.list" ${chroot_dir}/etc/apt/sources.list

#Set apt cache proxy in chroot
#echo 'Acquire::http { Proxy "http://127.0.0.1:3142"; };' | sudo tee ${chroot_dir}/etc/apt/apt.conf.d/00aptproxy

echo "Create a script to run in the chroot"
CHROOT_SCRIPT=/tmp/chroot_script.sh
cat > $CHROOT_SCRIPT <<EOF
#!/bin/bash

#Install packages needed for Live System
apt-get update
locale-gen "en_US.UTF-8"
dpkg-reconfigure --frontend=noninteractive locales
echo "Installing remix base"
apt-get install --yes ubuntu-standard ubuntu-minimal casper lupin-casper
#TODO: These are not listed on the ubuntu-mini-remix packages
#https://answers.launchpad.net/ubuntu-mini-remix/+faq/33
echo "Installing live packages"
apt-get install --yes discover laptop-detect os-prober
apt-get install --yes etc/apt/apt.conf.d/00aptproxy

#Add Ubiquity KDE front end
echo "Installing ubiquity"
apt-get install --yes ubiquity-frontend-kde

#Cleanup the chroot
#rm /var/lib/dbus/machine-id
#apt-get clean
#rm -rf /tmp/*
#rm /etc/resolv.conf
#umount -lf /proc
#umount -lf /sys
#umount -lf /dev/pts

EOF
 
chmod +x $CHROOT_SCRIPT
sudo mv $CHROOT_SCRIPT ${chroot_dir}/tmp/

echo "Run script in chroot"
sudo chroot ${chroot_dir} $CHROOT_SCRIPT
 
echo "Remove apt proxy from chroot"
sudo rm ${chroot_dir}/etc/apt/apt.conf.d/00aptproxy

#echo "Unbind /dev from chroot"
#sudo umount ${chroot_dir}/dev

#Make the image directory and the 3 required subdirectories.
mkdir -p "${image_dir}/casper"
mkdir -p "${image_dir}/isolinux"
mkdir -p "${image_dir}/install"

echo "Copy kernel and initrd from chroot to image"
cp ${chroot_dir}/boot/vmlinuz-*-generic "${image_dir}/casper/vmlinuz"
cp ${chroot_dir}/boot/initrd.img-*-generic "${image_dir}/casper/initrd.lz"

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
cp isolinux.txt "${image_dir}/isolinux"

#Provide configuration settings for the boot-loader.
#TODO Verify this as it is a sample
cp isolinux.cfg "${image_dir}/isolinux"

exit 666

#Create a manifest
sudo chroot ${chroot_dir} dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${image_dir}/casper/filesystem.manifest"
sudo cp -v "${image_dir}/casper/filesystem.manifest" "${image_dir}/casper/filesystem.manifest-desktop"

echo "Remove installer packages from the base system now we have created the installer"
REMOVE='ubiquity ubiquity-frontend-gtk ubiquity-frontend-kde casper lupin-casper live-initramfs user-setup discover1 xresprobe os-prober libdebian-installer4'
for i in $REMOVE
do
  sudo sed -i "/${i}/d" "${image_dir}/casper/filesystem.manifest-desktop"
done

echo "Compress the chroot dir to a file in the image dir"
sudo mksquashfs ${chroot_dir} "${image_dir}/casper/filesystem.squashfs"

#Then write the filesystem.size file, which is needed by the installer
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > "${image_dir}/casper/filesystem.size"

#This is needed to make the USB Creator work with this custom iso image.
touch "${image_dir}/ubuntu"
mkdir "${image_dir}/.disk"
cd "${image_dir}/.disk"
touch base_installable
echo "full_cd/single" > cd_type
#TODO: Make this version number a variable
echo "Ubuntu Remix 17.04" > info
#TODO: Make this URL a variable
echo "http//your-release-notes-url.com" > release_notes_url

cd "${work_dir}"
#Calculate MD5
sudo -s
(cd "${image_dir}" && find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)
exit

echo "Create iso from the image directory"
cd "${image_dir}"
volume_id=ubuntu-remix
sudo mkisofs -r -V "${volume_id}" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o "${iso_path}" .

echo "Change owner of iso to user"
cd "${script_dir}"
user_group=$(stat -c "%U:%G" .)
sudo chown "${user_group}" "${iso_path}"

mount |grep ${chroot_dir}
echo "Unmounting /proc from chroot"
sudo umount "${chroot_dir}/proc"

echo "Finished"

