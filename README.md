# Ubuntu-Mini-Respin

This is an attempt to recreate Minibuntu/Ubuntu Mini Remix.
https://fabrizioballiano.net/ubuntu-mini-remix/

The script creates an Ubuntu ISO with as few dependencies as possible to be used as a base for respins.

## Instructions

Since you are likely to want to run this multiple times, the script makes use of `squid` as a proxy to cache the deb files and the repository Release files. 
This is more reliable for offline work than `apt-cacherng` as squid can cache more than just the deb files.

The squid config is copied from `squid-deb-proxy` and has been modified slightly to run local to the project (instead of saving the cache/logs in the system dirs) and has been tweaked to work completely offline.

**Install squid**

    sudo apt install squid

**Start squid with the local config**

    ./caching-proxy.sh

**Run the main script**

    ./ubuntu-mini-respin.sh
 
## Tip and Guides

See here for tips on reducing debian size

https://wiki.debian.org/ReduceDebian


Guides on customising the Ubuntu LiveCD 

* https://help.ubuntu.com/community/LiveCDCustomization
* https://nathanpfry.com/how-to-customize-an-ubuntu-installation-disc/

Another script wrapping the above guide

https://pastebin.com/NQUTWC1y
