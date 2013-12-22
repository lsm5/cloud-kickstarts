#!/bin/bash -x
repoowner=lsm5
for size in small medium; do
    for ver in 20 rawhide; do
        export LIBGUESTFS_BACKEND=direct
        if [[ "$size" == 'medium' && "$ver" == '20' ]]; then
            repo=$repoowner/fedora
        else
            repo=$repoowner/fedora-$size-$ver
        fi
        appliance-creator -c container-$size-$ver.ks -d -v -t /tmp \
            -o /tmp/f$ver$size --name "fedora-$ver-$size" --release $ver \
            --format=qcow2
        virt-tar-out -a \
            /tmp/f$ver$size/fedora-$ver-$size/fedora-$ver-$size-sda.qcow2 \
            / - | gzip --best > /tmp/fedora-$ver-$size.tar.gz
        cat /tmp/fedora-$ver-$size.tar.gz | docker import - $repo
    done
done
