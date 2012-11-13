# This is a basic Fedora 18 spin designed to work in OpenStack and other
# private cloud environments. It's configured with cloud-init so it will
# take advantage of ec2-compatible metadata services for provisioning
# ssh keys. That also currently creates an ec2-user account; we'll probably
# want to make that something generic by default. The root password is empty
# by default.

lang en_US.UTF-8
keyboard us
timezone --utc America/New_York
auth --useshadow --enablemd5
selinux --enforcing
firewall --service=ssh
bootloader --timeout=3 --location=mbr --driveorder=sda
network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network,sshd,rsyslog


# Define how large you want your rootfs to be
part biosboot --fstype=biosboot --size=1 --ondisk sda
part / --size 4000 --fstype ext4 --ondisk sda

# Repositories
#repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-18&arch=$basearch
#temporarily hardcode because many mirrors don't have 0.7
repo --name=fedoradev --baseurl=http://linux.seas.harvard.edu/fedora/linux/development/18/x86_64/os/

# We start with @core, and then add a few more packages to make a nice
# functional Fedora-like but still reasonably minimal cloud image.
%packages --nobase
@core
cloud-init
kernel
man-db
grub2
# if we're not going to be installing firewalld, we need this
iptables-services

# and, some things from @core we can do without
-biosdevname
-plymouth
-linux-firmware
-NetworkManager
-polkit

%end

# more ec2-ify
%post --erroronfail

cat <<EOL > /etc/fstab
LABEL=_/   /         ext4    defaults        1 1
proc       /proc     proc    defaults        0 0
sysfs      /sys      sysfs   defaults        0 0
devpts     /dev/pts  devpts  gid=5,mode=620  0 0
tmpfs      /dev/shm  tmpfs   defaults        0 0
EOL


# grub tweaks
cat <<EOL > /etc/default/grub
GRUB_TIMEOUT=0
EOL
sed -ie 's/^set timeout=5/set timeout=0/' /boot/grub2/grub.cfg

# for EC2, need to figure out how to set up menu.list for pv-grub

# setup systemd to boot to the right runlevel
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# TODO: fix firewall

%end

