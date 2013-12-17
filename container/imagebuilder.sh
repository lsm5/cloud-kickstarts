#!/bin/bash -x
repoowner=lsm5
unset LIBGUESTFS_BACKEND
repo=$repoowner/fedora-imagebuilder
appliance-creator -c container-imagebuilder.ks -d -v -t /tmp \
    -o /tmp/fimagebuilder --name "fedora-imagebuilder" --release 20 \
    --format=qcow2
virt-tar-out -a \
    /tmp/fimagebuilder/fedora-imagebuilder/fedora-imagebuilder-sda.qcow2 / - | \
    gzip --best > /tmp/fedora-imagebuilder.tar.gz
export LIBGUESTFS_BACKEND=direct
cat /tmp/fedora-imagebuilder.tar.gz | docker import - $repo
