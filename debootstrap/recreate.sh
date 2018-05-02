#!/bin/bash
# recreate.sh – this file – creates the configuration file needed by tool "multistrap"
set -euo pipefail

WORKDIR="$(mktemp -d -t "ubuntu.XXXXXX")"

cat >multistrap.conf <<EOF
[General]
arch=amd64
noauth=true
cleanup=true
directory=$WORKDIR
debootstrap=
aptsources=
omitrequired=false

EOF

# For better legibility omit IJEFOQUV.
ordinals=("repoA" "repoB" "repoC" "repoD" "repoG")

n=0
while read source suite components; do
  sed -i \
    -e "/^debootstrap/s:\$: ${ordinals[$n]}:" \
    -e "/^aptsources/s:\$: ${ordinals[$n]}:" \
    multistrap.conf
  cat >>multistrap.conf <<EOP
[${ordinals[$n]}]
packages=
source=$source
suite=$suite
components=$components
omitdebsrc=true

EOP
  let n+=1
done < <(cat /etc/apt/sources.list | sed -n '/^deb/s/.*\(http.*\)/\1/p' | sort -u)

packages=($(gzip -dc /var/log/installer/initial-status.gz | sed -n 's/^Package: //p' | sort -u))
sed -i \
  -e "0,/^packages=/s:packages=:packages=${packages[*]}:" \
  multistrap.conf

printf "Run multistrap, inspect its results, and then:\n"
printf "  tar --one-file-system --sort=name \\ \n"
printf "    -C '%s' -caf rootfs.tar .\n" "${WORKDIR}"
