# Build a basic Fedora 14 AMI
lang en_US.UTF-8
keyboard us
timezone --utc America/New_York
auth --useshadow --enablemd5
selinux --enforcing
firewall --service=ssh
bootloader --timeout=1 --location=mbr --driveorder=sda
network --bootproto=dhcp --device=em1 --onboot=on
services --enabled=network,sshd,rsyslog

# By default the root password is emptied

#
# Define how large you want your rootfs to be
# NOTE: S3-backed AMIs have a limit of 10G
#
part / --size 10000 --fstype ext4 --ondisk sda

#
# Repositories
repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-15&arch=$basearch

#
#
# Add all the packages after the base packages
#
%packages --excludedocs --nobase --instLangs=en
@core
system-config-securitylevel-tui
audit
pciutils
bash
coreutils
kernel-PAE
grub
e2fsprogs
passwd
policycoreutils
chkconfig
rootfiles
yum
vim-minimal
acpid
openssh-clients
openssh-server
curl
sudo

#Allow for dhcp access
dhclient
iputils

%end

# more ec2-ify
%post --erroronfail

# disable root password based login
cat >> /etc/ssh/sshd_config << EOF
PermitRootLogin no
UseDNS no
EOF

sed 's|\(^PasswordAuthentication \)yes|\1no|' /etc/ssh/sshd_config

# create ec2-user
/usr/sbin/useradd ec2-user
/bin/echo -e 'ec2-user\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers

# set up ssh key fetching
cat >> /etc/rc.local << EOF
if [ ! -d /home/ec2-user/.ssh ]; then
  mkdir -p /home/ec2-user/.ssh
  chmod 700 /home/ec2-user/.ssh
fi

# Fetch public key using HTTP
ATTEMPTS=10
while [ ! -f /home/ec2-user/.ssh/authorized_keys ]; do
    curl -f http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key > /tmp/aws-key 2>/dev/null
    if [ \$? -eq 0 ]; then
        cat /tmp/aws-key >> /home/ec2-user/.ssh/authorized_keys
        chmod 0600 /home/ec2-user/.ssh/authorized_keys
        restorecon /home/ec2-user/.ssh/authorized_keys
        rm -f /tmp/aws-key
        echo "Successfully retrieved AWS public key from instance metadata"
    else
        FAILED=\$((\$FAILED + 1))
        if [ \$FAILED -ge \$ATTEMPTS ]; then
            echo "Failed to retrieve AWS public key after \$FAILED attempts, quitting"
            break
        fi
        echo "Could not retrieve AWS public key (attempt #\$FAILED/\$ATTEMPTS), retrying in 5 seconds..."
        sleep 5
    fi
done
EOF

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

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

# grub tweaks
sed -i -e 's/timeout=5/timeout=0/' \
    -e 's|root=[^ ]\+|root=LABEL=_/|' \
    -e '/splashimage/d' /boot/grub/grub.conf

# symlink grub.conf to menu.lst for use by EC2 pv-grub
pushd /boot/grub
ln -s grub.conf menu.lst
popd


%end

