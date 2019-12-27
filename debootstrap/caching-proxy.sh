#!/usr/bin/env bash

mkdir -p squid/var/log/squid-deb-proxy
mkdir -p squid/var/run/

echo "Starting an instance of squid using the working dir for caches and logs instead of the system dirs"
squid -Nf squid/squid-deb-proxy.conf
