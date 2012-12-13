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


# Define how large you want your rootfs to be
part biosboot --fstype=biosboot --size=1 --ondisk sda
part / --size 1024 --fstype ext4 --ondisk sda

# Repositories
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-18&arch=$basearch

# We start with @core, and then add a few more packages to make a nice
# functional Fedora-like but still reasonably minimal cloud image.
%packages --nobase
@core
kernel
grub2
firewalld
iptables-services


# and, some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-NetworkManager
-polkit

# ultra-minimal, in fact.
-e2fsprogs
-audit
-rsyslog
-parted
-openssh-clients
-rootfiles
-sendmail
-sudo

%end

# Configuration
%post --erroronfail

cat <<EOF > /etc/fstab
LABEL=_/   /         ext4    defaults        1 1
EOF


# grub tweaks
echo GRUB_TIMEOUT=0 > /etc/default/grub
sed -ie 's/^set timeout=5/set timeout=0/' /boot/grub2/grub.cfg

# for EC2, need to figure out how to set up menu.list for pv-grub

# setup systemd to boot to the right runlevel
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target

# because we didn't install rsyslog, enable persistent journal
mkdir /var/log/journal/ 

# this is installed by default but we don't need it in virt
yum -C -y remove linux-firmware

# remove firewalld; was supposed to be optional in F18, but is required to
# be present for image building. 
yum -C -y remove firewalld
#
yum -C -y remove cairo dbus-glib dbus-python ebtables fontconfig fontpackages-filesystem gobject-introspection js libdrm libpciaccess libpng libselinux-python libwayland-client libwayland-server libX11 libX11-common libXau libxcb libXdamage libXext libXfixes libXrender libXxf86vm mesa-libEGL mesa-libgbm mesa-libGL mesa-libglapi pixman polkit pycairo pygobject2 pygobject3 python-decorator python-slip python-slip-dbus

# Non-firewalld-firewall
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

# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros

%end

