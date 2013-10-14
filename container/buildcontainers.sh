#!/bin/bash -x
repoowner=mattdm
for size in small medium; do
for ver in 19 20; do
  if [[ "$size" == 'medium' ]]; then
     repo=$repoowner/fedora
  else
     repo=$repoowner/fedora-$size
  fi
  appliance-creator -c container-$size-$ver.ks -d -v -t /tmp \
     -o /tmp/f$ver$size --name "fedora-$ver-$size" --release $ver \
     --format=qcow2 && 
  virt-tar-out -a /tmp/f$ver$size/fedora-$ver-$size/fedora-$ver-$size-sda.qcow2 / - |
  docker import - $repo f$ver
done
done
