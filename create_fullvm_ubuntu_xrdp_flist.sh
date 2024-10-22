#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Check if API_KEY provided or not
if [ -z "$1" ]; then
    echo "Usage: $0 <API_KEY>"
    exit 2
fi

API_KEY=$1

echo "Installing arch-install-scripts package..."
apt-get update
apt-get install arch-install-scripts debootstrap -y

echo "Starting debootstrap..."
mkdir -p ubuntu-noble
debootstrap noble ubuntu-noble http://archive.ubuntu.com/ubuntu
echo "Debootstrap completed."

echo "Preparing chroot environment script..."
cat <<EOF > ubuntu-noble/root/setup_inside_chroot.sh
#!/bin/bash
set -x  # This will print each command before it's executed
export PATH=/usr/local/sbin/:/usr/local/bin/:/usr/sbin/:/usr/bin/:/sbin:/bin
rm /etc/resolv.conf
echo 'nameserver 1.1.1.1' > /etc/resolv.conf
apt-get update
apt-get install cloud-init openssh-server curl initramfs-tools xrdp ufw -y
cloud-init clean
apt-get install linux-modules-extra-6.8.0-31-generic -y
echo 'fs-virtiofs' >> /etc/initramfs-tools/modules
update-initramfs -c -k all

# Install XFCE and XRDP
apt-get install xfce4 xfce4-goodies xrdp sudo -y

# Create a non-root user for XRDP
useradd -m -s /bin/bash xrdpuser
echo "xrdpuser:xrdppassword" | chpasswd
usermod -aG sudo xrdpuser

# Configure XRDP for the new user
echo "xfce4-session" > /home/xrdpuser/.xsession
chown xrdpuser:xrdpuser /home/xrdpuser/.xsession

# Configure XRDP
sed -i 's/allowed_users=console/allowed_users=anybody/' /etc/X11/Xwrapper.config
systemctl enable xrdp

apt-get clean

# Set correct ownership and permissions for sudo
chown root:root /usr/bin/sudo
chmod 4755 /usr/bin/sudo

# Create the systemd service file for setting sudo permissions
cat << EOF2 > /etc/systemd/system/set-sudo-permissions.service
[Unit]
Description=Set correct ownership and permissions for sudo
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/bin/chown root:root /usr/bin/sudo && /bin/chmod 4755 /usr/bin/sudo'

[Install]
WantedBy=multi-user.target
EOF2

# Create ufw_setup.sh
cat << EOF3 > /root/ufw_setup.sh
#!/bin/bash

# Wait for /mnt/zosrc to be available
timeout=300
while [ ! -f /mnt/zosrc ] && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

if [ ! -f /mnt/zosrc ]; then
    echo "Error: /mnt/zosrc not found after waiting" >&2
    exit 1
fi

source /mnt/zosrc
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow from \${LOCAL_PC_IP}/32 to any port 3389
ufw limit ssh
EOF3
chmod +x /root/ufw_setup.sh

# Create xrdp_setup.sh
cat << EOF4 > /root/xrdp_setup.sh
#!/bin/bash
systemctl start xrdp
cd ~
echo "xfce4-session" | tee .xsession
systemctl restart xrdp
EOF4
chmod +x /root/xrdp_setup.sh

# Create xrdp_user.sh
cat << EOF5 > /root/xrdp_user.sh
#!/bin/bash

# Wait for /mnt/zosrc to be available
timeout=300
while [ ! -f /mnt/zosrc ] && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

if [ ! -f /mnt/zosrc ]; then
    echo "Error: /mnt/zosrc not found after waiting" >&2
    exit 1
fi

source /mnt/zosrc

# Only change password if XRDP_USER_PASSWORD is set
if [ -n "\${XRDP_USER_PASSWORD}" ]; then
    echo "xrdpuser:\${XRDP_USER_PASSWORD}" | chpasswd
fi
EOF5
chmod +x /root/xrdp_user.sh

# Create systemd services for the new scripts
cat << EOF6 > /etc/systemd/system/ufw-setup.service
[Unit]
Description=Setup UFW rules
After=network.target
Before=xrdp.service

[Service]
Type=oneshot
ExecStart=/root/ufw_setup.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF6

cat << EOF7 > /etc/systemd/system/xrdp-setup.service
[Unit]
Description=Setup XRDP
After=network.target ufw-setup.service
Before=xrdp.service

[Service]
Type=oneshot
ExecStart=/root/xrdp_setup.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF7

cat << EOF8 > /etc/systemd/system/xrdp-user-setup.service
[Unit]
Description=Setup XRDP user
After=network.target ufw-setup.service xrdp-setup.service
Before=xrdp.service

[Service]
Type=oneshot
ExecStart=/root/xrdp_user.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF8

# Enable the services
systemctl enable set-sudo-permissions.service
systemctl enable ufw-setup.service
systemctl enable xrdp-setup.service
systemctl enable xrdp-user-setup.service

EOF

chmod +x ubuntu-noble/root/setup_inside_chroot.sh

echo "Entering chroot environment..."
arch-chroot ubuntu-noble /root/setup_inside_chroot.sh
echo "Chroot setup completed."

echo "Cleaning up..."
rm ubuntu-noble/root/setup_inside_chroot.sh
rm -rf ubuntu-noble/dev/*

echo "Checking for extract-vmlinux..."
if ! command -v extract-vmlinux &>/dev/null; then
    echo "extract-vmlinux not found, installing..."
    curl -O https://raw.githubusercontent.com/torvalds/linux/master/scripts/extract-vmlinux
    chmod +x extract-vmlinux
    mv extract-vmlinux /usr/local/bin
fi
echo "Extracting kernel..."
extract-vmlinux ubuntu-noble/boot/vmlinuz | tee ubuntu-noble/boot/vmlinuz-6.8.0-31-generic.elf > /dev/null
mv ubuntu-noble/boot/vmlinuz-6.8.0-31-generic.elf ubuntu-noble/boot/vmlinuz-6.8.0-31-generic

echo "Creating tar archive..."
tar -czvf ubuntu-24.04_fullvm_xrdp.tar.gz -C ubuntu-noble .
echo "Tar archive created."

echo "Uploading to Threefold Hub..."
curl -v -X POST -H "Authorization: Bearer $API_KEY" -F "file=@ubuntu-24.04_fullvm_xrdp.tar.gz" https://hub.grid.tf/api/flist/me/upload
echo "Upload completed."