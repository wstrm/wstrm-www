---
title: "Gentoo with DM-Crypt LUKS and EFI"
date: "2018-06-16"
description: "Meta guide to install Gentoo with DM-Crypt LUKS and EFI."
categories: 
    - "gentoo"
    - "os"
    - "encryption"
---

This article serves as somekind of meta instruction for installing Gentoo with DM-Crypt LUKS. It's my preffered setup with a Gentoo with OpenRC and EFI running on an encrypted harddrive.

The guide is heavily based upon [Sakaki's EFI Install Guide](https://wiki.gentoo.org/wiki/Sakaki%28s_EFI_Install_Guide).

If this is your first time installing Gentoo it's probably a better idea to follow [Sakaki's EFI Install Guide](https://wiki.gentoo.org/wiki/Sakaki%28s_EFI_Install_Guide), or follow the [Gentoo's Handbook](https:/wiki.gentoo.org/wiki/Handbook:AMD64/Full/Installation)

## Burn Minimal Installation CD to USB

Download the Minimal Installation CD from: https://www.gentoo.org/downloads/

Write the ISO to the USB drive using DD:
```
dd if=/path/to/image.iso of=/dev/sdX bs=8192k
```

## Boot and connect to a network

Either connect a network cable, or connect to a WLAN using:
```
# Add AP w/ passphrase to config
wpa_passphrase "ESSID" > /etc/wpa.conf
<then type your WiFi access point passphrase (without quotes) and press Enter>

# Fix permissions
chmod -v 600 /etc/wpa.conf

# Check for available WLAN interface
ip a

# Connect using WLAN interface
wpa_supplicant -Dnl80211,wext -i<interface> -c/etc/wpa.conf -B 
```

## Create GPT partition on main storage

Find the main storage drive using:
```
lsblk
```

Run `parted` to create the GPT partition:
```
parted -a optimal /dev/sdX
```

Inside parted issue:
```
(parted) unit mib
(parted) mklabel gpt
(parted) mkpart grub 1 3
(parted) set 1 bios_grub on
(parted) mkpart boot fat32 3 515
(parted) set 2 BOOT on
(parted) mkpart lvm 515 -1
(parted) set 3 lvm on
(parted) print
(parted) quit
```

Make sure everything is correct:
```
lsblk
```

Overwrite the partitions with pseudo-random data (if you're paranoid):
```
dd if=/dev/urandom of=/dev/sdX{1..3} bs=1M
```

## Format main parition with LUKS
Let `cryptsetup` format `/dev/sdX3` as a LUKS partition:
```
cryptsetup --key-size 512 --hash sha512 luksFormat /dev/sdX3
```

Verify everything went well:
```
cryptsetup luksDump /dev/sdX3
```

## Setup LVM on main LUKS partition
Open the LUKS volume:
```
cryptsetup luksOpen /dev/sdX3 storage
```

Create LVM physical volume (PV):
```
pvcreate /dev/mapper/storage
```

Create LVM volume group (VG):
```
vgcreate main /dev/mapper/storage
```

Check the size of RAM:
```
grep MemTotal /proc/meminfo
```

Create LVM logical volume (LV) for swap:
```
lvcreate --size <size-of-ram+2>G --name swap main
```

Create LVM logical volume (LV) for root:
```
lvcreate --size 100%FREE --name root main
```

Make sure everything is setup correct:
```
pvdisplay
vgdisplay
lvdisplay
ls /dev/mapper
```

## Format and mount the logical volumes (LVs):
Format swap:
```
mkswap -L "swap" /dev/mapper/main-swap
```

Format root:
```
mkfs.ext4 -L "root" /dev/mapper/main-root
```

Format efi/boot:
```
mkfs.vfat -F32 /dev/sdX2
```

Activate swap:
```
swapon /dev/mapper/main-swap
```

Mount root directory at pre-existing `/mnt/gentoo` mountpoint:
```
mount -t ext4 /dev/mapper/main-root /mnt/gentoo
```

Create needed directories in root:
```
mkdir /mnt/gentoo/{home,boot,boot/efi}
```

Mount home directory:
```
mount -t ext4 /dev/mapper/main-home /mnt/gentoo/home
```

Take note of the PARTUUID for the main partition:
```
blkid /dev/sdX3
```

## Check date and time
Make sure the time is correct:
```
date
```

## Fetch and unpack the Gentoo Stage 3 Tarball:

Change to the root mountpoint:
```
cd /mnt/gentoo
```

Download the latest Stage 3 files:
```
links http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.bz2
```

Look for (find the files where YYYYMMDD is the latest date):
```
/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.bz2
/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.bz2.CONTENTS
/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.bz2.DIGESTS.asc
```

Retrieve the public key:
```
gpg --recv-keys 0x9E6438C817072058
```

Verify the cryptographic signature:
```
gpg --verify stage3-amd64-*.DIGESTS.asc
```

Check the digests:
```
awk '/SHA512 HASH/{getline;print}' stage3-amd64-*.DIGESTS.asc | sha512sum -- check
```

Double check you're in the `/mnt/gentoo` directory, then issue:
```
tar xvjpf stage3-amd64-*.tar.bz2
```

Remove the Stage 3 files:
```
rm stage3-amd64-*
```

Return home:
```
cd
```

## Setup Portage
Edit the `/mnt/gentoo/etc/portage/make.conf` file (modify for your computer):
```
# The holy USE
USE="device-mapper"

# C and C++ compiler options for GCC.
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="${CFLAGS}"
MAKEOPTS="-j4" # 4 threads per job
EMERGE_DEFAULT_OPTS="--jobs 2 --load-average 7.2" # 2 parallel jobs, at 8*0.9 load (90 % load on all cores)
CPU_FLAGS_X86="aes avx f16c mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3" # check w/ cpuid2cpuflags

# Only free software, please.
ACCEPT_LICENSE="-* @FREE CC-Sampling-Plus-1.0"

# WARNING: Changing your CHOST is not something that should be done lightly.
# Please consult http://www.gentoo.org/doc/en/change-chost.xml before changing.
CHOST="x86_64-pc-linux-gnu"

# Use the 'stable' branch.
ACCEPT_KEYWORDS="amd64"

# Additional USE flags in addition to those specified by the current profile.
USE="${CPU_FLAGS_X86}"

# Important Portage directories.
PORTDIR="/usr/portage"
DISTDIR="${PORTDIR}/distfiles"
PKGDIR="${PORTDIR}/packages"

# Turn on logging - see http://gentoo-en.vfose.ru/wiki/Gentoo_maintenance.
PORTAGE_ELOG_CLASSES="info warn error log qa"
PORTAGE_ELOG_SYSTEM="save"
# Logs go to /var/log/portage/elog by default - view them with elogviewer.

# Settings for X11 (make sure these are correct for your hardware).
VIDEO_CARDS="intel i965"
INPUT_DEVICES="evdev synaptics"

# Dracut (initramfs)
DRACUT_MODULES="crypt lvm"
```

## Prepare and enter `chroot`

Select the correct mirror for your location:
```
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
```

Setup `/mnt/gentoo/etc/portage/repos.conf` directory:
```
mkdir -p /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
```

Copy resolv.conf so DNS works in `chroot`:
```
cp -L /etc/resolv.conf /mnt/gentoo/etc/
```

If we're using WLAN, also run:
```
cp /etc/wpa.conf /mnt/gentoo/etc/
```

Mount `/proc`, `/sys` and `/dev`:
```
mount -t proc none /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/dev
```

Enter `chroot`:
```
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"
```

## Install the Portage Tree

Install the latest Portage repository tree snapshot (it'll create all directories it's complaining about):
```
(chroot) emerge-webrsync
```

Update the Portage tree:
```
(chroot) emerge --sync
```

Make sure the Portage package is up-to-date:
```
(chroot) emerge --ask --verbose --oneshot portage
```

Check which baseline profile to use:
```
(chroot) eselect profile list
```

Select the correct profile (change `1` to the correct one):
```
(chroot) eselect profile set 1
```

Make a sanity check of the profile, `make.conf`, enviroment etc.:
```
(chroot) emerge --info
```

## Setup timezone and locale

Check for your timezone:
```
(chroot) ls /usr/share/zoneinfo
```

Set the timezone:
```
(chroot) echo "Europe/Stockholm" > /etc/timezone
```

Reconfigure the `sys-libs/timezone-data` package so it picks up the new timezone:
```
(chroot) emerge --config sys-libs/timezone-data
```

Set the locale by uncommenting the correct ones in `/etc/locale.gen`, in my case:
```
en_US.UTF-8 UTF-8
```

Generate the new locales:
```
(chroot) locale-gen
```

Find the number for the locale:
```
(chroot) eselect locale list
```

Set the locale to the `C` locale (we'll change to the actual later):
```
(chroot) eselect locale set 1
```

Reload the enviroment:
```
(chroot) env-update && source /etc/profile && export PS1="(chroot) $PS1"
```

Find the correct key map:
```
(chroot) ls /usr/share/keymaps/i386/qwerty
```

Choose the correct one (strip out`.map.gz`) and edit `/etc/conf.d/keymaps`:
```
keymap="sv-latin1"
```

## Some minor fixes (optional)

If you want to use LibreSSL instead of OpenSSL follow the guide here:
[https://wiki.gentoo.org/wiki/Project:LibreSSL](https://wiki.gentoo.org/wiki/Project:LibreSSL)

## Create directories for package.use, package.mask, etc.:
```
(chroot) mkdir -p -v /etc/portage/package.use
(chroot) touch /etc/portage/package.use/zzz_via_autounmask
(chroot) mkdir -p -v /etc/portage/package.mask
(chroot) mkdir -p -v /etc/portage/package.unmask
(chroot) touch /etc/portage/package.unmask/zzz_via_autounmask
(chroot) mkdir -p -v /etc/portage/package.accept_keywords
(chroot) touch /etc/portage/package.accept_keywords/zzz_via_autounmask
```

## Finally, make sure system is up-to-date

Update `@world`:
```
(chroot) emerge --ask --verbose --deep --with-bdeps=y --newuse --update @world
```

Make sure everything is configured correctly:
```
(chroot) dispatch-conf
```

## Build the Linux kernel

Permit licenses needed to build kernel:
```
(chroot) mkdir -p -v /etc/portage/package.license
(chroot) touch /etc/portage/package.license/zzz_via_autounmask
(chroot) echo "sys-kernel/gentoo-sources freedist" >> /etc/portage/package.license/gentoo-sources
(chroot) echo "sys-kernel/linux-firmware freedist" >> /etc/portage/package.license/linux-firmware
```

Fetch the kernel sources and firmware:
```
(chroot) emerge --ask --verbose sys-kernel/gentoo-sources
(chroot) emerge --ask --verbose sys-kernel/linux-firmware
```

Make sure `/usr/src/linux` points to current kernel version:
```
(chroot) readlink -v /usr/src/linux
(chroot) eselect kernel list
```

Configure the kernel:
```
Gentoo Linux > Support for init systems, system and service managers > [*] systemd
General setup > [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support
Enable the block layer > Partition Types > [*]   EFI GUID Partition support
Processor type and features > [*] EFI runtime service support
Device Drivers > Generic Driver Options > () path to uevent helper
Device Drivers > Multiple devices driver support (RAID and LVM) > <*>   Device mapper support > <*>     Crypt target support
Device Drivers > Multiple devices driver support (RAID and LVM) > <*>   Device mapper support > <*>     Mirror target
Device Drivers > Graphics support > Support for frame buffer devices > [*]   Enable firmware EDID
Device Drivers > Graphics support > Support for frame buffer devices > [*]   EFI-based Framebuffer Support
Device Drivers > Graphics support > Console display driver support > <*> Framebuffer Console support
Firmware Drivers > EFI (Extensible Firmware Interface)  Support > <*> EFI Variable Support via sysfs

```

Build and install the kernel:
```
(chroot) make && make modules_install && make install

```

Prepare for initramfs:
```
echo "sys-kernel/dracut" >> /etc/portage/package.keywords/dracut
emerge -av sys-kernel/dracut
echo 'GRUB_CMDLINE_LINUX="rd.lvm.vg=main"' >> /etc/default/grub
```

__TBC__
