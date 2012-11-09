# Build a basic Fedora 18 AMI
lang en_US.UTF-8
keyboard us
timezone --utc America/New_York
auth --useshadow --enablemd5
selinux --enforcing
firewall --service=ssh
bootloader --timeout=1 --location=mbr --driveorder=sda
network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network,sshd,rsyslog

# By default the root password is emptied

#
# Define how large you want your rootfs to be
# NOTE: S3-backed AMIs have a limit of 10G
#
part / --size 10000 --fstype ext4 --ondisk sda

# This will let fussy, fussy grub2 install, if we
# decide we want that.
#part biosboot --fstype=biosboot --size=1 --ondisk sda


#
# Repositories
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-18&arch=$basearch

#
#
# Add all the packages after the base packages
#
%packages --nobase
@core
pciutils
kernel
man-db

-biosdevname

# package to setup cloudy bits for us
cloud-init

%end

# more ec2-ify
%post --erroronfail

# fstab mounting is different for x86_64 and i386
cat <<EOL > /etc/fstab
LABEL=_/   /         ext4    defaults        1 1
proc       /proc     proc    defaults        0 0
sysfs      /sys      sysfs   defaults        0 0
devpts     /dev/pts  devpts  gid=5,mode=620  0 0
tmpfs      /dev/shm  tmpfs   defaults        0 0
EOL
if [ ! -d /lib64 ] ; then

cat <<EOL >> /etc/fstab
/dev/xvda3 swap      swap    defaults        0 0
EOL

# workaround xen performance issue (bz 651861)
echo "hwcap 1 nosegneg" > /etc/ld.so.conf.d/libc6-xen.conf

fi

# idle=nomwait is to allow xen images to boot and not try use cpu features that are not supported
# grub tweaks
sed -i -e 's/timeout=5/timeout=0/' \
    -e 's|root=[^ ]\+|root=LABEL=_/  idle=halt|' \
    -e '/splashimage/d' \
    /boot/grub/grub.conf

# the firewall rules get saved as .old  without this we end up not being able 
# ssh in as iptables blocks access

rename -v  .old "" /etc/sysconfig/*old

# symlink grub.conf to menu.lst for use by EC2 pv-grub
pushd /boot/grub
ln -s grub.conf menu.lst
popd

# setup systemd to boot to the right runlevel
rm /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

%end
