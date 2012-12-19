# This is a basic Fedora 18 spin designed to work in Amazon EC2.
# It's configured with cloud-init so it will take advantage of
# ec2-compatible metadata services for provisioning ssh keys. That also
# currently creates an ec2-user account; we'll probably want to make that
# something generic by default. The root password is empty by default.
#
# Note that unlike the standard F18 install, this image has /tmp on disk
# rather than in tmpfs, since memory is usually at a premium.
#
# It additionally configures _no_ local firewall, in line with EC2
# recommendations that security groups be used instead.



lang en_US.UTF-8
keyboard us
timezone --utc America/New_York

auth --useshadow --enablemd5
selinux --enforcing

firewall --disabled

bootloader --timeout=0 --location=mbr --driveorder=sda

network --bootproto=dhcp --device=eth0 --onboot=on
services --enabled=network,sshd,rsyslog,iptables,cloud-init,cloud-init-local,cloud-config,cloud-final

part biosboot --fstype=biosboot --size=1 --ondisk sda
part / --size 4096 --fstype ext4 --ondisk sda

# Repositories
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-18&arch=$basearch


# Package list.
%packages --nobase
@core
kernel

# cloud-init does magical things with EC2 metadata, including provisioning
# a user account with ssh keys.
cloud-init

# Needed initially, but removed below.
firewalld

# cherry-pick a few things from @standard
tmpwatch
tar
rsync

# Some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-NetworkManager
-polkit

%end



%post --erroronfail

echo -n "Writing fstab"
cat <<EOF > /etc/fstab
LABEL=_/   /         ext4    defaults        1 1
EOF
echo .

echo -n "Grub tweaks"
echo GRUB_TIMEOUT=0 > /etc/default/grub
sed -i '1i# This file is for use with pv-grub; legacy grub is not installed in this image' /boot/grub/grub.conf
sed -i 's/^timeout=5/timeout=0/' /boot/grub/grub.conf
# need to file a bug on this one
sed -i 's/root=.*/root=LABEL=_\//' /boot/grub/grub.conf
echo .
if ! [[ -e /boot/grub/menu.lst ]]; then
  echo -n "Linking menu.lst to old-style grub.conf for pv-grub"
  ln /boot/grub/grub.conf /boot/grub/menu.lst
  ln -sf /boot/grub/grub.conf /etc/grub.conf
fi

# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# If you want to remove rsyslog and just use journald, also uncomment this.
#echo -n "Enabling persistent journal"
#mkdir /var/log/journal/ 
#echo .

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
yum -C -y remove linux-firmware

# Remove firewalld; was supposed to be optional in F18, but is required to
# be present for install/image building.
echo "Removing firewalld."
yum -C -y remove firewalld


# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

# Uncomment this if you want to use cloud init but suppress the creation
# of an "ec2-user" account. This will, in the absence of further config,
# cause the ssh key from a metadata source to be put in the root account.
#cat <<EOF > /etc/cloud/cloud.cfg.d/50_suppress_ec2-user_use_root.cfg
#users: []
#disable_root: 0
#EOF

# Temporary kludge in case https://bugzilla.redhat.com/show_bug.cgi?id=887363
# does not make F18 final release.
if [[ $( rpm -q --qf '%{v}-%{r}' cloud-init) == "0.7.1-1.fc18" ]]; then
echo "Detected older cloud-init; generating config file now."
cat <<EOF > /etc/cloud/cloud.cfg
users:
 - default

disable_root: 1
ssh_pwauth:   0

locale_configfile: /etc/sysconfig/i18n
mount_default_fields: [~, ~, 'auto', 'defaults,nofail', '0', '2']
resize_rootfs_tmp: /dev
ssh_deletekeys:   0
ssh_genkeytypes:  ~
syslog_fix_perms: ~

cloud_init_modules:
 - bootcmd
 - write-files
 - resizefs
 - set_hostname
 - update_hostname
 - update_etc_hosts
 - rsyslog
 - users-groups
 - ssh

cloud_config_modules:
 - mounts
 - locale
 - set-passwords
 - timezone
 - puppet
 - chef
 - salt-minion
 - mcollective
 - disable-ec2-metadata
 - runcmd

cloud_final_modules:
 - rightscale_userdata
 - scripts-per-once
 - scripts-per-boot
 - scripts-per-instance
 - scripts-user
 - ssh-authkey-fingerprints
 - keys-to-console
 - phone-home
 - final-message

system_info:
  default_user:
    name: ec2-user
    lock_passwd: true
    gecos: EC2 user
    groups: [wheel, adm]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/bash
  distro: fedora
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd
# vim:syntax=yaml
EOF
fi


echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros
echo "(Don't worry -- that out-of-space error was expected.)"

%end

