# Lindows7 Installer and Live Boot Setup

This document describes the Calamares installer and live boot configuration for Lindows7.

## Overview

The Lindows7 distribution now includes:
- **Calamares Installer**: A graphical installer for installing Lindows7 to target systems
- **Live Boot**: A live session mode for trying Lindows7 without installation
- **Live User**: Pre-configured user with username `lindows7` and password `lindows7`

## Boot Options

### BIOS/UEFI GRUB Menu

1. **Lindows7 Live** (default)
   - Boots into a live session with Plasma desktop
   - Allows testing Lindows7 without installation
   - Login: `lindows7` / `lindows7`
   - Calamares installer available from application menu

2. **Lindows7 Install**
   - Boots into live session and automatically starts Calamares installer
   - Provides direct installation experience
   - Login: `lindows7` / `lindows7`
   - Installer launches automatically after desktop loads

3. **Lindows7 Live with speakup screen reader**
   - Live session with accessibility support
   - Includes speakup screen reader for visually impaired users

### BIOS Syslinux Menu

Same options as GRUB with appropriate labels for BIOS systems.

## Live User Configuration

- **Username**: `lindows7`
- **Password**: `lindows7`
- **Groups**: wheel, lp, video, network, storage, audio, optical, floppy, uucp, scanner, games
- **Sudo**: Full sudo access without password prompt
- **Autologin**: Configured for SDDM display manager

## Calamares Configuration

### Main Settings
- **Configuration**: `/etc/calamares/settings.conf`
- **Branding**: `/etc/calamares/branding/lindows7/branding.desc`
- **Modules**: `/etc/calamares/modules/*.conf`

### Installation Sequence
1. Welcome
2. Locale selection
3. Keyboard layout
4. Partition setup
5. User configuration
6. Summary
7. Execution (partition, mount, unpack, system setup, bootloader, etc.)
8. Finished

### Key Module Configurations

#### Partition
- Default filesystem: ext4
- EFI partition: /boot/efi (512MiB)
- GPT partition table
- User can choose from multiple swap options

#### Users
- Default groups include wheel for sudo access
- Configured for autologin with user `lindows7`
- Password requirements: minimal (no restrictions)

#### Display Manager
- SDDM as display manager
- Autologin enabled for live user

#### Bootloader
- GRUB as bootloader
- EFI boot loader ID: "Lindows7"
- EFI system partition: /boot/efi

#### Packages
- Includes base system, Plasma desktop, networking, audio, and utilities
- Matching the package list from the main distribution

## Live Session Scripts

### Systemd Service
- **Service**: `live-medium.service`
- **Location**: `/usr/lib/systemd/system/live-medium.service`
- **Enabled**: Automatically starts at boot
- **Function**: Sets up live environment

### Setup Scripts

#### `/usr/local/bin/live-setup`
- Creates live user `lindows7` with password `lindows7`
- Sets hostname to `lindows7-live`
- Enables NetworkManager and SDDM services
- Configures Calamares autostart if `desktop=calamares` kernel parameter is present

#### `/usr/local/bin/live-session-start`
- Creates desktop shortcut for Calamares installer
- Automatically launches Calamares if `desktop=calamares` parameter is set
- Sets up installer on desktop for easy access

#### `/usr/local/bin/calamares-launch`
- Checks for `desktop=calamares` kernel parameter
- Can be used to launch Calamares directly

## Building the ISO

To build the Lindows7 ISO with the installer and live boot functionality:

```bash
# Ensure you have archiso installed
sudo pacman -S archiso

# Build the ISO
sudo mkarchiso -v profile/
```

The resulting ISO will be in the `out/` directory.

## Testing

### Live Session Testing
1. Build the ISO
2. Boot the ISO in a virtual machine or from USB
3. Select "Lindows7 Live" from boot menu
4. Login with `lindows7` / `lindows7`
5. Verify desktop loads and applications work
6. Launch Calamares from application menu or desktop shortcut

### Installation Testing
1. Build the ISO
2. Boot the ISO
3. Select "Lindows7 Install" from boot menu
4. Verify Calamares launches automatically
5. Complete installation process
6. Reboot and verify installed system

## Troubleshooting

### Calamares Issues
- Check logs in `/var/log/calamares/`
- Verify all module configurations are valid YAML
- Ensure required packages are installed

### Live Session Issues
- Check `live-medium.service` status: `systemctl status live-medium.service`
- Review setup script output in journal logs
- Verify systemd service is enabled: `systemctl is-enabled live-medium.service`

### Boot Issues
- Verify kernel parameters in GRUB/Syslinux configs
- Check that `desktop=calamares` parameter is correctly set for install option
- Ensure squashfs image is properly generated

## File Structure

```
profile/
├── airootfs/
│   ├── etc/
│   │   ├── calamares/
│   │   │   ├── settings.conf
│   │   │   ├── branding/
│   │   │   │   └── lindows7/
│   │   │   │       └── branding.desc
│   │   │   └── modules/
│   │   │       ├── partition.conf
│   │   │       ├── unpackfs.conf
│   │   │       ├── users.conf
│   │   │       └── ... (other modules)
│   │   └── systemd/
│   │       └── system/
│   │           ├── live-medium.service
│   │           └── multi-user.target.wants/
│   │               └── live-medium.service
│   └── usr/
│       ├── local/bin/
│       │   ├── live-setup
│       │   ├── live-session-start
│       │   └── calamares-launch
│       ├── lib/systemd/system/
│       │   └── live-medium.service
│       └── share/applications/
│           └── calamares.desktop
├── grub/
│   └── grub.cfg (updated with Lindows7 entries)
├── syslinux/
│   ├── archiso_sys.cfg (updated default)
│   └── archiso_sys-linux.cfg (updated with Lindows7 entries)
├── packages.x86_64 (includes calamares)
└── profiledef.sh (updated with file permissions)
```

## Customization

### Changing Live User
Edit `/usr/local/bin/live-setup` and modify:
- Username in `useradd` command
- Password in `chpasswd` command
- Groups in useradd `-G` parameter

### Modifying Installer Modules
Edit configuration files in `/etc/calamares/modules/`:
- Each module has its own `.conf` file
- Changes affect the installation process

### Customizing Boot Menu
Edit:
- GRUB: `profile/grub/grub.cfg`
- Syslinux: `profile/syslinux/archiso_sys-linux.cfg`

## Notes

- The live user has full sudo access for testing purposes
- In production, consider restricting sudo access or using different credentials
- The Calamares configuration is designed for a standard desktop installation
- Additional customization may be needed for specific use cases
- The unpackfs module copies the live filesystem to the target system during installation