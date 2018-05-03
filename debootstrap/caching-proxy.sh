#!/usr/bin/env bash

#This starts an instance of squid using the working dir for caches and logs instead of the system dirs
squid -Nf squid/squid-deb-proxy.conf
