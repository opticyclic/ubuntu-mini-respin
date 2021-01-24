# Creating A Minimal ISO With Debootstrap

This is information and a script to create a minimal ISO using `debootstrap` from scratch using the guide on the [wiki](https://help.ubuntu.com/community/LiveCDCustomizationFromScratch).

Since you are likely to want to run this multiple times, the script makes use of `squid` as a proxy to cache the deb files and the repository Release files.
This is more reliable for offline work than `apt-cacherng` as squid can cache more than just the deb files.

The squid config is copied from `squid-deb-proxy` and has been modified slightly to run local to the project (instead of saving the cache/logs in the system dirs) and has been tweaked to work completely offline.

**Install squid**

    sudo apt install squid

**Start squid with the local config**

    ./caching-proxy.sh

**Run the main script**

    ./ubuntu-mini-respin.sh
 