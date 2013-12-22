#!/bin/bash -x
repoowner=lsm5
rm -f /home/$repoowner/fedora-imagebuilder.tar.gz
repo=$repoowner/fedora-imagebuilder
sudo appliance-creator -c container-imagebuilder.ks -d -v -t /home/$repoowner \
    -o /home/$repoowner --name "fedora-imagebuilder" --release 20 \
    --format=qcow2
virt-tar-out -a \
    /home/$repoowner/fedora-imagebuilder/fedora-imagebuilder-sda.qcow2 / - | \
    gzip --best > /home/$repoowner/fedora-imagebuilder.tar.gz
export LIBGUESTFS_BACKEND=direct
cat /home/$repoowner/fedora-imagebuilder.tar.gz | docker import - $repo
