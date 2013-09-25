#!/bin/bash -x
for size in small medium; do
for ver in 19 20; do
  appliance-creator -c container-$size-$ver.ks -d -v -t /tmp \
     -o /tmp/f$ver$size --name "fedora-$ver-$size" --release $ver \
     --format=qcow2 && 
  virt-tar-out -a /tmp/f$ver$size/fedora-$ver-$size/fedora-$ver-$size-sda.qcow2 / - |
  docker import - fedora$ver-$size
done
done
