# Creating A Minimal ISO With ubuntu-defaults-builder

The original Ubuntu Mini Remix used `ubuntu-defaults-builder` to create the ISO instead of creating everything from scratch.

https://gist.github.com/fballiano/357810cf7eb70f09d87e

The contents of the gist are pasted below for reference.

## Original Script

    #!/bin/bash
    # user: ubuntu pass: just hit ENTER
    
    apt-get install vim ubuntu-defaults-builder live-build uck syslinux-utils coreutils
    # open /usr/share/livecd-rootfs/live-build/auto/config and add PROJECT=base where there are all the variables
    ubuntu-defaults-template ubuntu-defaults-umr
    ubuntu-defaults-image --package ubuntu-defaults-umr_0.1_all.deb
    mv binary.hybrid.iso ubuntu-mini-remix-15.10-amd64.iso
    md5sum ubuntu-mini-remix-15.10-amd64.iso>ubuntu-mini-remix-15.10-amd64.iso.md5
    mv ubuntu-mini-remix-15.10-amd64.iso* 15.10/
    
    lb clean; rm -rf auto cache local
    
    ubuntu-defaults-image --package ubuntu-defaults-umr_0.1_all.deb --arch i386
    mv binary.hybrid.iso ubuntu-mini-remix-15.10-i386.iso
    md5sum ubuntu-mini-remix-15.10-i386.iso>ubuntu-mini-remix-15.10-i386.iso.md5
    mv ubuntu-mini-remix-15.10-i386.iso* 15.10/

It is missing a step where it creates the debian package `buntu-defaults-umr_0.1_all.deb` out of the config files
See below for how it is done with `dpkg-buildpackage`

## What Is Ubuntu Defaults Builder?

The ubuntu-defaults-builder project allows you to easily create a "default settings" package for Ubuntu and then build a customized image with it.
The main purpose for this is to  provide a standard and safe way to create localized Ubuntu images, or OEM custom projects.
       
This is split into a few different parts. See

http://manpages.ubuntu.com/manpages/focal/man1/ubuntu-defaults-template.1.html
and
http://manpages.ubuntu.com/manpages/focal/man1/ubuntu-defaults-image.1.html

The first part we are interested in is `ubuntu-defaults-template`.

After installing ubuntu-defaults-builder, you create your config area:

    ubuntu-defaults-template ubuntu-defaults-mydistro

This creates a directory named ubuntu-defaults-mydistro. Inside that directory are simple config files that you can modify.

After modifying the config files with you package the files into a deb.

    dpkg-buildpackage -us -uc

The options are `-us or --unsigned-source` and `-uc or --unsigned-changes` since we aren't signing it.

This creates the file in the parent directory with a default version number of 0.1.

e.g. `ubuntu-defaults-mydistro_0.1_all.deb`

You can now create the iso:

    cd ..
    ubuntu-defaults-image --package ubuntu-defaults-mydistro_0.1_all.deb

This creates output files binary.hybrid.iso and livecd.ubuntu.iso.

## Problems

This no longer works after Xenial. You get an error:

    Unable to locate package syslinux-themes-ubuntu-<version>

 - https://bugs.launchpad.net/ubuntu/+source/ubuntu-defaults-builder/+bug/1636030
 - https://bugs.launchpad.net/ubuntu/+source/ubuntu-defaults-builder/+bug/1053021

The issue stems from the fact that no `syslinux-themes-ubuntu` package has been created since Xenial.

https://code.launchpad.net/ubuntu/+source/syslinux-themes-ubuntu
