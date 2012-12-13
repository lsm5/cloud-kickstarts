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

# this is actually not used, but a static firewall
# matching these rules is generated below.
firewall --service=ssh --service=http --service=https

bootloader --timeout=0 --location=mbr --driveorder=sda

network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network,sshd,rsyslog,iptables


part biosboot --fstype=biosboot --size=1 --ondisk sda
part / --size 1024 --fstype ext4 --ondisk sda

# Repositories
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-18&arch=$basearch


# Packag list.
# "Obsessively minimal as we can reasonably get and still be Fedora."
%packages --nobase
@core
kernel

# Not needed with pv-grub (as in EC2). Would be nice to have
# something smaller for F19 (syslinux?), but this is what we have now.
grub2

# Needed initially, but removed below.
firewalld

# Basic firewall. If you're going to rely on your cloud service's
# security groups you can remove this.
iptables-services

# Some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-NetworkManager
-polkit

# These are "leaf" packages which can be done without in an ultra-minimal
# install, but which actually remove typical functionality
-e2fsprogs
-audit
-rsyslog
-parted
-openssh-clients
-rootfiles
-sendmail
-sudo

%end



%post --erroronfail

echo -n "Writing fstab"
cat <<EOF > /etc/fstab
LABEL=_/   /         ext4    defaults        1 1
EOF
echo .

echo -n "Grub tweaks"
echo GRUB_TIMEOUT=0 > /etc/default/grub
sed -ie 's/^set timeout=5/set timeout=0/' /boot/grub2/grub.cfg
echo .

# for EC2, need to figure out how to set up menu.list for pv-grub


# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# because we didn't install rsyslog, enable persistent journal
echo -n "Enabling persistent journal"
mkdir /var/log/journal/ 
echo .

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
yum -C -y remove linux-firmware

# Remove firewalld; was supposed to be optional in F18, but is required to
# be present for install/image building.
echo "Removing firewalld and dependencies"
yum -C -y remove firewalld
# These are all pulled in by firewalld
yum -C -y remove cairo dbus-glib dbus-python ebtables fontconfig fontpackages-filesystem gobject-introspection js libdrm libpciaccess libpng libselinux-python libwayland-client libwayland-server libX11 libX11-common libXau libxcb libXdamage libXext libXfixes libXrender libXxf86vm mesa-libEGL mesa-libgbm mesa-libGL mesa-libglapi pixman polkit pycairo pygobject2 pygobject3 python-decorator python-slip python-slip-dbus

# Non-firewalld-firewall
echo -n "Writing static firewall"
cat <<EOF > /etc/sysconfig/iptables
# Simple static firewall loaded by iptables.service. Replace
# this with your own custom rules, run lokkit, or switch to 
# shorewall or firewalld as your needs dictate.
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 22 -j ACCEPT
-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 80 -j ACCEPT
-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
echo .

# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros
echo "(Don't worry -- that out-of-space error was expected.)"

%end

