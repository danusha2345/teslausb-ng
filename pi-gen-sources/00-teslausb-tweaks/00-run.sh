#!/bin/bash -e
touch "${ROOTFS_DIR}/boot/ssh"
install -m 755 files/rc.local                             "${ROOTFS_DIR}/etc/"
install -m 666 files/teslausb_setup_variables.conf.sample "${ROOTFS_DIR}/boot/firmware/teslausb_setup_variables.conf"
install -m 666 files/wpa_supplicant.conf.sample           "${ROOTFS_DIR}/boot/firmware"
install -m 666 files/run_once                             "${ROOTFS_DIR}/boot/firmware"
install -d "${ROOTFS_DIR}/root/bin"

# ensure dwc2 module is loaded
echo "dtoverlay=dwc2" >> "${ROOTFS_DIR}/boot/firmware/config.txt"

# remove unwanted packages, disable unwanted services, and disable swap.
# Several entries here are tolerant of missing units/files because pi-gen
# master no longer ships resize2fs_once / the /etc/init.d firstboot
# helper that the original marcone/teslausb image expected.
on_chroot << EOF
apt-get remove -y --allow-change-held-packages --purge triggerhappy userconf-pi dphys-swapfile firmware-libertas firmware-realtek firmware-atheros mkvtoolnix || true
apt-get -y autoremove || true
systemctl disable keyboard-setup || true
systemctl disable resize2fs_once 2>/dev/null || true
systemctl disable dpkg-db-backup 2>/dev/null || true
update-rc.d -f resize2fs_once remove 2>/dev/null || true
rm -f /etc/init.d/resize2fs_once
rm -f /usr/share/initramfs-tools/scripts/local-premount/firstboot
update-initramfs -u || true
EOF
