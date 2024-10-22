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
apt-get install cloud-init openssh-server curl initramfs-tools -y
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

# Setup firewall rules
ufw allow 3389/tcp
ufw allow ssh
echo "y" | ufw enable

apt-get clean

# Set correct ownership and permissions for sudo
chown root:root /usr/bin/sudo
chmod 4755 /usr/bin/sudo

chmod +x /usr/local/bin/*

# Enable the service
systemctl enable set_sudo_permissions.service
systemctl enable user_password.service

EOF

chmod +x ubuntu-noble/root/setup_inside_chroot.sh

# Copy services and scripts into the VM
cp ./services/* ubuntu-noble/etc/systemd/system/ 2>/dev/null || echo "Warning: Could not copy service files"
cp ./scripts/* ubuntu-noble/usr/local/bin/ 2>/dev/null || echo "Warning: Could not copy script files"

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