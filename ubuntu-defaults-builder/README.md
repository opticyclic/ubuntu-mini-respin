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
