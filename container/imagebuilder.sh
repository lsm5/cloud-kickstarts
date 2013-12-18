#!/bin/bash -x
repoowner=lsm5
repo=$repoowner/fedora-imagebuilder
unset LIBGUESTFS_BACKEND
appliance-creator -c container-imagebuilder.ks -d -v -t /home/$repoowner \
    -o /home/$repoowner/fimagebuilder --name "fedora-imagebuilder" --release 20 \
    --format=qcow2
LIBGUESTFS_BACKEND=direct virt-tar-out -a \
    /home/$repoowner/fimagebuilder/fedora-imagebuilder/fedora-imagebuilder-sda.qcow2 / - | \
    gzip --best > /home/$repoowner/fedora-imagebuilder.tar.gz
cat /home/$repoowner/fedora-imagebuilder.tar.gz | docker import - $repo
