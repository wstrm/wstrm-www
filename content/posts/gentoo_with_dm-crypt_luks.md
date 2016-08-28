---
title: "Gentoo with DM-Crypt LUKS and EFI (Work In Progress)"
date: "2016-05-21"
description: "Meta guide to install Gentoo with DM-Crypt LUKS and EFI."
categories: 
    - "gentoo"
    - "os"
    - "encryption"
---

This article serves as somekind of meta instruction for installing Gentoo with DM-Crypt LUKS.

The guide is heavily based upon *Sakaki's EFI Install Guide*: https://wiki.gentoo.org/wiki/Sakaki%27s_EFI_Install_Guide

If this is your first time installing Gentoo it's probably a better idea to follow *Sakaki's EFI Install Guide*, or follow *Gentoo's Handbook*: https:/wiki.gentoo.org/wiki/Handbook:AMD64/Full/Installation

## Burn Minimal Installation CD to USB

Download the Minimal Installation CD from: https://www.gentoo.org/downloads/

Write the ISO to the USB drive using DD:
```
dd if=/path/to/image.iso of=/dev/sdX bs=8192k
```

## Boot and connect to a network

Either connect a network cable, or connect to a WLAN using:
```
iwconfig eth0 essid <ssid-of-network>

# set hex WEP key
iwconfig eth0 key <hex-key>
# or use ASCII WEP key
iwconfig eth0 key s:<ascii-key>
```

## Prepare USB-key and its filesystem

Check which USB storage device to use:
```
lsblk
```

After you have found the USB storage device create a primary partition on it:
```
parted -a optimal /dev/sdY
```

Then inside parted issue these commands:
```
(parted) mklabel gpt
(parted) mkpart primary fat32 0% 100%
(parted) set 1 BOOT on
(parted) quit
```

Format the USB storage device to `fat32`:
```
mkfs.vfat -F32 /dev/sdY1
```

Temporarily mount the partition:
```
mkdir /tmp/efiboot
mount -t vfat /dev/sdY1 /tmp/efiboot
```

## Create Keyfile for LUKS
```
export GPG_TTY=$(tty)
dd if=/dev/urandom bs=8388607 count=1 | gpg --symmetric --cipher-algo AES256 --output /tmp/efiboot/<hostname>-luks-key.gpg
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
(parted) unit s
(parted) print free

...

Number  Start       End         Size        File System   Name          Flags
        32s         251658206s  251658173s  Free Space

...

(parted) mkpart primary 2048s 100%
```

Make sure everything is correct:
```
lsblk
```

Overwrite the partition with pseudo-random data:
```
dd if=/dev/urandom of=/dev/sdXn bs=1M
```

## Format main parition with LUKS
Unlock USB keyfile and let `cryptsetup` format it as a LUKS partition:
```
gpg --decrypt /tmp/efiboot/<hostname>-luks-key.gpg | cryptsetup --key-size 512 --hash sha512 --key-file - luksFormat /dev/sdXn
```

Verify everything went well:
```
cryptsetup luksDump /dev/sdXn
```

Backup the LUKS header to the USB storage device (incase the header is damaged and is needed for restoring data):
```
cryptsetup luksHeaderBackup /dev/sdXn --header-backup-file /tmp/efiboot/<hostname>-luks-header.img
```

## Setup LVM on main LUKS partition
Open the LUKS volume:
```
gpg --decrypt /tmp/efiboot/<hostname>-luks-key.gpg | cryptsetup --key-file - luksOpen /dev/sdXn storage
```

Create LVM physical volume (PV):
```
pvcreate /dev/mapper/storage
```

Create LVM volume group (VG):
```
vgcreate vg1 /dev/mapper/storage
```

Check the size of RAM:
```
grep MemTotal /proc/meminfo
```

Create LVM logical volume (LV) for swap:
```
lvcreate --size <size-of-ram+2>G --name swap vg1
```

Create LVM logical volume (LV) for root:
```
lvcreate --size 40G --name root vg1
```

Create LVM logical volume (LV) for home:
```
lvcreate --extents 95%FREE --name home vg1
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
mkswap -L "swap" /dev/mapper/vg1-swap
```

Format root:
```
mkfs.ext4 -L "root" /dev/mapper/vg1-root
```

Format home:
```
mkfs.ext4 -m 0 -L "home" /dev/mapper/vg1-home
```

Activate swap:
```
swapon /dev/mapper/vg1-swap
```

Mount root directory at pre-existing `/mnt/gentoo` mountpoint:
```
mount -t ext4 /dev/mapper/vg1-root /mnt/gentoo
```

Create needed directories in root:
```
mkdir /mnt/gentoo/{home,boot,boot/efi}
```

Mount home directory:
```
mount -t ext4 /dev/mapper/vg1-home /mnt/gentoo/home
```

Unmount USB boot key's EFI partition:
```
umount /tmp/efiboot
```

Take note of the PARTUUIDs for the USB storage partition and the main partition:
```
blkid /dev/sdYn /dev/sdXn
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

Edit `/mnt/gentoo/root/.bashrc`:
```
export NUMCPUS=$(nproc)
export NUMCPUSPLUSONE=$(( NUMCPUS + 1 ))
export MAKEOPTS="-j${NUMCPUSPLUSONE} -l${NUMCPUS}"
export EMERGE_DEFAULT_OPTS="--jobs=${NUMCPUSPLUSONE} --load-average=${NUMCPUS}"
```

Copy the `.bash_profile` file (make sure `VIDEO_CARDS` and `INPUT_DEVICES` are correct):
```
cp /mnt/gentoo/etc/skel/.bash_profile /mnt/gentoo/root/
```

Edit the `/mnt/gentoo/etc/portage/make.conf` file:
```
# C and C++ compiler options for GCC.
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="${CFLAGS}"

# Note: MAKEOPTS and EMERGE_DEFAULT_OPTS are set in .bashrc

# Only free software, please.
ACCEPT_LICENSE="-* @FREE CC-Sampling-Plus-1.0"

# WARNING: Changing your CHOST is not something that should be done lightly.
# Please consult http://www.gentoo.org/doc/en/change-chost.xml before changing.
CHOST="x86_64-pc-linux-gnu"

# Use the 'stable' branch.
ACCEPT_KEYWORDS="amd64"

# Additional USE flags in addition to those specified by the current profile.
CPU_FLAGS_X86=""
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

Edit the `/mnt/gentoo/etc/portage/repos.conf/gentoo.conf` file:
```
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /usr/portage
sync-type = rsync
auto-sync = yes
```

Select mirror for `sync-uri` (rsync server location):
```
mirrorselect -i -r -o | sed 's/^SYNC=/sync-uri = /;s/"//g' >> /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
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

Set the locale by uncommenting the correct ones in `/etc/locale.gen`:
```
en_US ISO-8859-1
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
keymap="sv"
```

## Some minor fixes (optional)

If you want to use LibreSSL instead of OpenSSL follow the guide here:
[https://wiki.gentoo.org/wiki/Project:LibreSSL](https://wiki.gentoo.org/wiki/Project:LibreSSL)

Use directories for package.use, package.mask, etc.:
```
(chroot) mkdir -p -v /etc/portage/package.use
(chroot) touch /etc/portage/package.use/zzz_via_autounmask
(chroot) mkdir -p -v /etc/portage/package.mask
(chroot) mkdir -p -v /etc/portage/package.unmask
(chroot) touch /etc/portage/package.unmask/zzz_via_autounmask
(chroot) mkdir -p -v /etc/portage/package.accept_keywords
(chroot) touch /etc/portage/package.accept_keywords/zzz_via_autounmask
```

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

Emerge `genkernel-next` and additional packages:
```
(chroot) echo -e "# ensure we can generate a bootable kernel and initramfs\nsys-kernel/genkernel-next cryptsetup gpg" >> /etc/portage/package.use/genkernel-next
(chroot) emerge --ask --verbose sys-kernel/genkernel-next app-crypt/efitools
```

Setup buildkernel:
```
(chroot) buildkernel --easy-setup
```
Example configuration:
```
... significant amounts of output suppressed in what follows ...
* buildkernel: Warning: This system wasn't booted under UEFI, cannot check boot entries
* Current configuration (from /etc/buildkernel.conf):
	EFI system partition UUID:  2498f874-ad8f-484e-8aba-81ac1c9665b6
	LUKS root partition UUID:   8111286a-d24e-4ba2-b6af-d0650fab4130
	GPG keyfile partition UUID: DEFAULT (=EFI system partition UUID)
	GPG keyfile (for LUKS):     luks-key.gpg                        
	EFI boot directory:         /EFI/Boot                           
	EFI boot file:              bootx64.efi                         
  Plymouth theme:             NONE (textual boot)                 
	Boot-time keymap:           us                         
	Init system:                systemd                             

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 1 then Enter
* Please choose which EFI system partition to use (or GO BACK):
	Num Partition UUID                       Path       USB Win Use
	--- ------------------------------------ ---------- --- --- ---
	1) 2498f874-ad8f-484e-8aba-81ac1c9665b6 /dev/sdb1   Y  ??? [*]
	2) f236e16c-ca97-4c36-b0d5-4196fa1e9930 /dev/sda2   N  ??? [ ]
	3) GO BACK
	Your choice: selected item is OK so press 3 then Enter
* Current configuration (from /etc/buildkernel.conf - MODIFIED):
	... as before ...

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 2 then Enter
* Please choose which LUKS partition contains the root LVM logical volume:
	Num Partition UUID                       Path       USB Use
	--- ------------------------------------ ---------- --- ---
	1) 8111286a-d24e-4ba2-b6af-d0650fab4130 /dev/sda5   N  [*]
	2) GO BACK
	Your choice: selected item is OK so press 2 then Enter
* Current configuration (from /etc/buildkernel.conf):
	... as before ...

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 3 then Enter
* Current LUKS key settings:
* Using a GPG-encrypted keyfile for LUKS:
*  KEYFILEPARTUUID unset: assuming GPG keyfile on EFI system partition
* Please choose your desired LUKS key setting (or GO BACK):
	1) Use GPG-encrypted keyfile on EFI system partition
	2) Use GPG-encrypted keyfile on specific USB partition...
	3) Use fallback passphrase (no keyfile)
	4) GO BACK
	Your choice: selected item is OK so press 4 then Enter
* Current configuration (from /etc/buildkernel.conf):
	... as before ...

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 4 then Enter
* Current EFI boot file setting:
* EFI boot file path: /EFI/Boot/bootx64.efi
*  (under EFI system partition mountpoint)
* Please choose your desired EFI boot file setting (or GO BACK):
	1) Use /EFI/Boot/bootx64.efi (recommended for initial USB install)
	2) Use /EFI/Microsoft/Boot/bootmgfw.efi (fallback for certain systems)
	3) Use /EFI/Boot/gentoo.efi (recommended for post-install use)
	4) GO BACK
	Your choice: selected item is OK so press 4 then Enter
* Current configuration (from /etc/buildkernel.conf):
	... as before ...

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 5 then Enter
* Current boot splash settings:
* Using textual boot (no Plymouth)
* Please choose your desired boot splash setting (or GO BACK):
	1) Use textual boot (no Plymouth)
	2) Use Plymouth graphical boot splash ('fade-in')
	3) GO BACK
	Your choice: selected item is OK so press 3 then Enter
* Current configuration (from /etc/buildkernel.conf):
	... as before ...

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 6 then Enter
* Please choose your desired boot-time keymap (or GO BACK):
* Boot-time keymap is currently 'us'
	1) azerty     9) cz      17) gr       25) mk        33) sg       41) us
	2) be        10) de      18) hu       26) nl        34) sk-y     42) wangbe
	3) bg        11) dk      19) il       27) no        35) sk-z     43) sf
	4) br-a      12) dvorak  20) is       28) pl        36) slovene  44) GO BACK
	5) br-l      13) es      21) it       29) pt        37) trf
	6) by        14) et      22) jp       30) ro        38) trq
	7) cf        15) fi      23) la       31) ru        39) ua
	8) croat     16) fr      24) lt       32) se        40) uk
	Your choice: press 32 then Enter
	NB - select the appropriate keymap for your system!
* Keymap selected to be 'se'
* Current configuration (from /etc/buildkernel.conf - MODIFIED):
	EFI system partition UUID:  2498f874-ad8f-484e-8aba-81ac1c9665b6
	LUKS root partition UUID:   8111286a-d24e-4ba2-b6af-d0650fab4130
	GPG keyfile partition UUID: DEFAULT (=EFI system partition UUID)
	GPG keyfile (for LUKS):     luks-key.gpg                        
	EFI boot directory:         /EFI/Boot                           
	EFI boot file:              bootx64.efi                         
	Plymouth theme:             NONE (textual boot)                 
	Boot-time keymap:           se                                  
	Init system:                systemd                             

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 7 then Enter
* Current init system settings:
* Targeting systemd init
* Please choose your desired init system setting (or GO BACK):
	1) systemd (select if unsure)  3) GO BACK
	2) OpenRC
	Your choice: selected item is OK so press 3 then Enter 
	NB - users wanting to use OpenRC should press 2 then Enter here
* Current configuration (from /etc/buildkernel.conf):
	... as before ...

* Please choose an option:
	1) Set EFI system partition  6) Set boot-time keymap
	2) Set LUKS root partition   7) Set init system
	3) Set LUKS key options      8) Exit without saving
	4) Set EFI boot file path    9) Save and exit
	5) Set boot splash options
	Your choice: press 9 then Enter
* Configuration saved to /etc/buildkernel.conf.
* Be sure to run buildkernel, to rebuild the kernel with the new
* settings, before rebooting.
... significant amounts of output suppressed in the above ...
```

Build the kernel using `buildkernel`:
```
(chroot) buildkernel --ask --verbose
```

TBC
