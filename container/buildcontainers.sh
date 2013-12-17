#!/bin/bash -x
repoowner=lsm5
for size in medium; do
    for ver in 20; do
        unset LIBGUESTFS_BACKEND
        if [[ "$size" == 'medium' ]]; then
            repo=$repoowner/fedora
        else
            repo=$repoowner/fedora-$size
        fi
        appliance-creator -c container-$size-$ver.ks -d -v -t /tmp \
            -o /tmp/f$ver$size --name "fedora-$ver-$size" --release $ver \
            --format=qcow2
        virt-tar-out -a \
            /tmp/f$ver$size/fedora-$ver-$size/fedora-$ver-$size-sda.qcow2 \
            / - | gzip --best > fedora-$ver-$size.tar.gz
        export LIBGUESTFS_BACKEND=direct
        cat fedora-$ver-$size.tar.gz | docker import - $repo:f$ver
    done
done
