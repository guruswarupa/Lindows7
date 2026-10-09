#!/usr/bin/env bash

iso_name="lindows7"
iso_label="LINDOWS7_202608"
iso_publisher="Lindows7"
iso_application="Lindows7 Live/Install Media"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"

buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')

airootfs_image_type="squashfs"
airootfs_image_tool_options=(
    '-comp' 'xz'
    '-Xbcj' 'x86'
    '-b' '1M'
    '-Xdict-size' '1M'
)

bootstrap_packages="/home/guru/Projects/Lindows7/profile/bootstrap_packages"
pacman_conf="/home/guru/Projects/Lindows7/profile/pacman.conf"
file_permissions=(
  ["/root"]="0:0:750"
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/liveuser"]="0:0:440"
  ["/etc/skel/Desktop/install-lindows7.desktop"]="0:0:755"
  ["/usr/local/bin/live-setup"]="0:0:755"
  ["/usr/local/bin/live-session-start"]="0:0:755"
  ["/usr/local/bin/calamares-launch"]="0:0:755"
)
