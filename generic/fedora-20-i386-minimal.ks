# This is a basic Fedora 20 spin designed to work in OpenStack and other
# private cloud environments. This particular kickstart is designed to
# be as obsessively minimal as we can be and still be Fedora. Because
# this has not traditionally been a priority, that's not particularly
# very small, making this in some ways an academic exercise, but it's also
# a base for the more complete kickstarts.
#
# If you're interested in making this more minimal, big problems to solve
# are the not-needed-for-cloud kernel modules and the gigantic locale
# database. After that, it's chipping at dependencies.
#
# This kickstart file is designed to be used with appliance-creator and
# may need slight modification for use with actual anaconda or other tools.
# We intend to target anaconda-in-a-vm style image building for F20.

lang en_US.UTF-8
keyboard us
timezone --utc Etc/UTC

auth --useshadow --enablemd5
selinux --enforcing
rootpw --lock --iscrypted locked

# this is actually not used, but a static firewall
# matching these rules is generated below.
firewall --service=ssh

bootloader --timeout=1 --extlinux

network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network,sshd,rsyslog,iptables


part / --size 2048 --fstype ext4


# Repositories
#repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-20&arch=$basearch
#repo --name=fedora-updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f20&arch=$basearch
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=rawhide&arch=$basearch


# Package list.
# "Obsessively minimal as we can reasonably get and still be Fedora."
%packages --nobase
@core
grubby
kernel-PAE

# We need this image to be portable; also, rescue mode isn't useful here.
dracut-nohostonly
dracut-norescue

# Not needed with pv-grub (as in EC2), and pulled in automatically
# by anaconda, but appliance-creator needs the hint
syslinux-extlinux 

# Needed initially, but removed below.
firewalld

# Basic firewall. If you're going to rely on your cloud service's
# security groups you can remove this.
iptables-services

# Some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-NetworkManager
-iprutils

# These are "leaf" packages which can be done without in an ultra-minimal
# install, but which actually remove typical functionality
-e2fsprogs
-audit
-rsyslog
-parted
-openssh-clients
-polkit
-rootfiles
-sendmail
-sudo

%end



%post --erroronfail

# workaround xen performance issue (bz 651861; see also bz 708406)
echo "hwcap 1 nosegneg" > /etc/ld.so.conf.d/libc6-xen.conf

# older versions of livecd-tools do not follow "rootpw --lock" line above
# https://bugzilla.redhat.com/show_bug.cgi?id=964299
passwd -l root

# Kickstart specifies timeout in seconds; syslinux uses 10ths.
# 0 means wait forever, so instead we'll go with 1.
sed -i 's/^timeout 10/timeout 1/' /boot/extlinux/extlinux.conf

# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
yum -C -y remove linux-firmware

# Remove firewalld; was supposed to be optional in F18+, but is required to
# be present for install/image building.
echo "Removing firewalld and dependencies"
yum -C -y remove firewalld --setopt="clean_requirements_on_remove=1"

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
#-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 80 -j ACCEPT
#-A INPUT -m conntrack --ctstate NEW -m tcp -p tcp --dport 443 -j ACCEPT
-A INPUT -j REJECT --reject-with icmp-host-prohibited
-A FORWARD -j REJECT --reject-with icmp-host-prohibited
COMMIT
EOF
echo .

# Another one needed at install time but not after that, and it pulls
# in some unneeded deps (like, newt and slang)
echo "Removing authconfig."
yum -C -y remove authconfig --setopt="clean_requirements_on_remove=1"

echo -n "Network fixes"
# initscripts don't like this file to be missing.
cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
EOF

# For cloud images, 'eth0' _is_ the predictable device name, since
# we don't want to be tied to specific virtual (!) hardware
rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

# simple eth0 config, again not hard-coded to the build hardware
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
EOF

# generic localhost names
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF
echo .


# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

# appliance-creator does not make this important file.
if [ ! -e /etc/sysconfig/kernel ]; then
echo "Creating /etc/sysconfig/kernel."
cat <<EOF > /etc/sysconfig/kernel
# UPDATEDEFAULT specifies if new-kernel-pkg should make
# new kernels the default
UPDATEDEFAULT=yes

# DEFAULTKERNEL specifies the default kernel package type
DEFAULTKERNEL=kernel-PAE
EOF
fi

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

echo "Cleaning old yum repodata."
yum clean all
truncate -c -s 0 /var/log/yum.log

echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros
echo "(Don't worry -- that out-of-space error was expected.)"

%end

