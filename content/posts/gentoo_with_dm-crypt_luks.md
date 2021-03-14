---
title: "Gentoo with DM-Crypt LUKS and EFI"
date: "2018-06-16"
lastmod: "2019-05-29"
description: "Meta guide to install Gentoo with DM-Crypt LUKS and EFI."
aliases: "/post/gentoo_with_dm-crypt_luks/"
tags:
    - "gentoo"
    - "os"
    - "encryption"
---

## What?!
This article serves as somekind of meta instruction for installing Gentoo with DM-Crypt LUKS. It's my preferred setup with a Gentoo with OpenRC and EFI running on an encrypted harddrive.

The guide is heavily based upon [Sakaki's EFI Install Guide](https://wiki.gentoo.org/wiki/Sakaki%28s_EFI_Install_Guide).

If this is your first time installing Gentoo it's probably a better idea to follow [Sakaki's EFI Install Guide](https://wiki.gentoo.org/wiki/Sakaki%28s_EFI_Install_Guide), or follow the [Gentoo's Handbook](https:/wiki.gentoo.org/wiki/Handbook:AMD64/Full/Installation)

<!--more-->

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
chmod 600 /etc/wpa.conf

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
(parted) mkpart boot fat32 1 251
(parted) set 1 boot on
(parted) mkpart root 251 -1
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
cryptsetup --key-size 512 --hash sha512 luksFormat /dev/sdX2
```

Verify everything went well:
```
cryptsetup luksDump /dev/sdX2
```

Open LUKS partition:
```
cryptsetup luksOpen /dev/sdX2 root
```

Format root:
```
mkfs.ext4 -L "root" /dev/mapper/root
```

Format efi/boot:
```
mkfs.vfat -F32 /dev/sdX1
```

Mount root directory at pre-existing `/mnt/gentoo` mountpoint:
```
mount -t ext4 /dev/mapper/root /mnt/gentoo
```

Create needed directories in root:
```
mkdir /mnt/gentoo/{home,boot,boot/efi}
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
links http://distfiles.gentoo.org/
```

Look for (find the files where YYYYMMDD is the latest date):
```
/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.xz
/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.xz.CONTENTS
/releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-YYYYMMDD.tar.xz.DIGESTS.asc
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
tar xvJpf stage3-amd64-*.tar.xz --xattrs-include='*.*' --numeric-owner
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
# Modify to fit your preferences.
USE="unicode savedconfig offensive alsa zsh-completion dmenu"

# C and C++ compiler options for GCC.
CFLAGS="-march=native -O2 -pipe"
CXXFLAGS="${CFLAGS}"

# Threads and jobs for my PC, with 16 threads.
MAKEOPTS="-j8" # 8 threads per job
EMERGE_DEFAULT_OPTS="--jobs 2 --load-average 14.4" # 2 parallel jobs, at 16*0.9 load (90 % load on all cores)

CPU_FLAGS_X86="aes avx f16c mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3" # check w/ cpuid2cpuflags

# Only free software, please.
ACCEPT_LICENSE="-* @FREE"

# WARNING: Changing your CHOST is not something that should be done lightly.
# Please consult http://www.gentoo.org/doc/en/change-chost.xml before changing.
CHOST="x86_64-pc-linux-gnu"

# Use the 'stable' branch.
ACCEPT_KEYWORDS="amd64"

# Important Portage directories.
PORTDIR="/usr/portage"
DISTDIR="${PORTDIR}/distfiles"
PKGDIR="${PORTDIR}/packages"

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C

# Turn on logging - see http://gentoo-en.vfose.ru/wiki/Gentoo_maintenance.
# Logs go to /var/log/portage/elog by default - view them with elogviewer.
PORTAGE_ELOG_CLASSES="info warn error log qa"
PORTAGE_ELOG_SYSTEM="save"

# Ensure elogs saved in category subdirectories.
# Build binary packages as a byproduct of each emerge, a useful backup.
FEATURES="split-elog buildpkg"

# Settings for X11 (make sure these are correct for your hardware).
VIDEO_CARDS="intel i965"
INPUT_DEVICES="libinput"
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

Move to the `/usr/src/linux` directory, and run `make menuconfig` to configure
the kernel:
```
(chroot) cd /usr/src/linux
(chroot) make menuconfig
```

Configure the kernel:
```
General setup > [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support
General setup > Initial RAM filesystem and RAM disk (initramfs/initrd) support > Initramfs source file(s) (/usr/src/initramfs)

Enable the block layer > Partition Types > [*]   EFI GUID Partition support

Processor type and features > [*] EFI runtime service support
Processor type and features > EFI runtime service support > <*> EFI stub support
Processor type and features > [*] Built-in kernel command line (root=/dev/mapper/root)

Device Drivers > Generic Driver Options > [] Support for uevent helper
Device Drivers > Generic Driver Options > () path to uevent helper
Device Drivers > Multiple devices driver support (RAID and LVM) > <*>   Device mapper support > <*>     Crypt target support

Device Drivers > Multiple devices driver support (RAID and LVM) > <*>   Device mapper support > <*>     Mirror target
Device Drivers > Graphics support > Support for frame buffer devices > [*]   Enable firmware EDID
Device Drivers > Graphics support > Support for frame buffer devices > [*]   EFI-based Framebuffer Support
Device Drivers > Graphics support > Console display driver support > <*> Framebuffer Console support

# You probably want USB 3.0 on most modern systems.
Device Drivers > USB support > <*> xHCI HCD (USB 3.0) support

Firmware Drivers > EFI (Extensible Firmware Interface)  Support > <*> EFI Variable Support via sysfs

Cryptographic API > <*> SHA512 digest algorithm (SSSE3/AVX/AVX2)
Cryptographic API > <*> XTS support
Cryptographic API > <*> AES cipher algorithms (x86_64)

# Enable this if you're using any x86_64 Intel CPU
Cryptographic API > <*> AES cipher algorithms (AES-NI)

Cryptographic API > <*> User-space interface for hash algorithms
Cryptographic API > <*> User-space interface for symmetric key cipher algorithms
```

Add required USE-flags for initramfs in `/etc/portage/package.use/initramfs`:
```
sys-apps/busybox static
sys-fs/cryptsetup static kernel -gcrypt -openssl

# Sadly, we need lvm for cryptsetup to work...
# required by sys-fs/cryptsetup-1.7.5::gentoo[static,-static-libs]
# required by cryptsetup (argument)
>=dev-libs/libgpg-error-1.29 static-libs
# required by sys-fs/cryptsetup-1.7.5::gentoo[static,-static-libs]
# required by cryptsetup (argument)
>=sys-apps/util-linux-2.30.2-r1 static-libs
# required by sys-fs/cryptsetup-1.7.5::gentoo[static,-static-libs]
# required by cryptsetup (argument)
>=sys-fs/lvm2-2.02.145-r2 static-libs
# required by sys-fs/cryptsetup-1.7.5::gentoo[static,-static-libs]
# required by cryptsetup (argument)
>=dev-libs/popt-1.16-r2 static-libs
# required by sys-fs/lvm2-2.02.145-r2::gentoo[udev]
# required by sys-fs/cryptsetup-1.7.5::gentoo[static,-static-libs]
# required by cryptsetup (argument)
>=virtual/libudev-232 static-libs
# required by virtual/libudev-232::gentoo[-systemd,static-libs]
# required by sys-fs/lvm2-2.02.145-r2::gentoo[udev]
# required by sys-fs/cryptsetup-1.7.5::gentoo[static,-static-libs]
# required by cryptsetup (argument)
>=sys-fs/eudev-3.2.5 static-libs
```

Install `busybox` and `cryptsetup`:
```
(chroot) emerge -av sys-fs/cryptsetup sys-apps/busybox
```

Create initramfs:
```
(chroot) mkdir -p /usr/src/initramfs/{bin,dev,run,etc,lib,lib64,mnt/root,proc,root,sbin,sys,usr/sbin,usr/bin}
(chroot) cp -a /dev/{null,console,tty,sdX1,sdX2} /usr/src/initramfs/dev/ # Replace X with correct drive letter.
(chroot) cp -a /dev/{urandom,random} /usr/src/initramfs/dev
(chroot) cp -a /sbin/cryptsetup /usr/src/initramfs/sbin/cryptsetup
(chroot) cp -a /bin/busybox /usr/src/initramfs/bin/busybox
(chroot) chroot /usr/src/initramfs /bin/busybox --install -s
```

Create `/usr/src/initramfs/init` with the following content:
```
#!/bin/busybox sh

die() {
	echo "Something went wrong. Dropping to a shell."
	exec sh
}

# Mount the /proc and /sys filesystems.
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t devtmpfs none /run

# Be a little bit more quiet.
echo 0 > /proc/sys/kernel/printk
clear

wait # For dev.

# Open encrypted partition, and place at /dev/mapper/root.
cryptsetup open $(findfs PARTLABEL=root) root && root=/dev/mapper/root || die

wait # For cryptsetup.

# It's okay to speak again.
echo 1 > /proc/sys/kernel/printk

mount -o ro /dev/mapper/root /mnt/root || die

# Clean up
umount /proc
umount /sys
umount /dev
umount /run

# Switch to real root.
exec switch_root /mnt/root /sbin/init || die
```

## Make `init` executable:
```
(chroot) chmod +x /usr/src/initramfs/init
```

Make sure we don't compile in an old initramfs:
```
(chroot) rm /usr/src/linux/usr/initramfs_data.cpio*
```

Build and install the kernel:
```
(chroot) make && make modules_install
```

Mount the boot partition (NOTE: Update drive letter):
```
(chroot) mount /dev/sdX1 /boot
```

Manually copy the kernel to the default EFI boot location:
```
(chroot) mkdir -p /boot/EFI/Boot
(chroot) cp /usr/src/linux/arch/x86_64/boot/bzImage /boot/EFI/Boot/bootx64.efi
```

Add `root` filesystem to `/etc/fstab`:
```
(chroot) echo "/dev/mapper/root / ext4 defaults,noatime,errors=remount-ro,discard   0 1" >> /etc/fstab
```

Install some usefull utilities before reboot:
```
(chroot) emerge -a net-misc/dhcpcd app-misc/screen
(chroot) emerge -a net-wireless/wpa_supplicant # If you use WiFi.
```

Set the root password:
```
(chroot) passwd root
```

Set the hostname:
```
(chroot) echo -n "myWonderfulComputer" > /etc/hostname
```

Reboot:
```
(chroot) exit
reboot # When you lose the connection, press: <Enter>, then '~', then '.'.
```

## What if something went wrong?!
If the something goes wrong during boot, boot using the USB with the minimal
install and enter the `chroot` again with:
```
cryptsetup luksOpen /dev/sdX2 root
mount -t ext4 /dev/mapper/root /mnt/gentoo
mount -t proc none /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/dev
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"
```

## Add user
Now, when you've succesfully booted into your new system, login as root and
create a new user that can use `sudo`:
```
emerge -a app-admin/sudo
useradd -m -G users,wheel,audio,video -s /bin/bash wstrm # Change to your username.
passwd wstrm # You'll get prompted to set the users password.
```

Enter `visudo` and uncomment the `# %wheel ALL=(ALL) NOPASSWD: ALL` block:
```
visudo # Uncomment the block, and save and exit.
```

## Install my favorite Portage set
Below you have my favorites, it contains a X11 environment running `dwm`. Add it
to `/etc/portage/sets/favorites`:
```
# Portage
app-eselect/eselect-repository
app-portage/cpuid2cpuflags
app-portage/eix
app-portage/repoman
app-portage/gentoolkit

# ZSH
app-shells/zsh
app-shells/zsh-completions
app-shells/gentoo-zsh-completions

# Mutt
app-text/antiword
app-text/extract_url
app-text/mupdf
mail-client/mutt
media-libs/exiftool

# Neovim
app-editors/neovim
media-fonts/powerline-symbols

# Python
dev-python/pip
dev-python/virtualenv

# C
dev-util/ctags
dev-util/strace

# Git
dev-vcs/git
dev-vcs/git-lfs

# Go
dev-lang/go

# Backup
sys-process/cronie
app-backup/restic

# Remote
net-misc/mosh

# Connectivity
net-misc/dhcpcd
net-wireless/wpa_supplicant
net-vpn/openvpn

# Powersave
sys-apps/hprofile

# Time
net-misc/chrony

# Tools
app-admin/pass
app-admin/stow
app-admin/sudo
app-arch/unzip
app-arch/zip
app-misc/screen
app-text/tree
media-gfx/feh
media-gfx/scrot
media-video/ffmpeg
media-sound/alsa-utils
net-analyzer/nethogs
net-analyzer/tcpdump
net-analyzer/traceroute
net-dns/bind-tools
sys-apps/pciutils
net-misc/youtube-dl
sys-apps/mlocate
sys-apps/ripgrep
sys-process/htop
www-client/lynx

# Sound
media-libs/alsa-lib

# X11 system
x11-base/xorg-drivers
x11-base/xorg-server
x11-wm/dwm

# X11 apps
x11-apps/xprop
x11-misc/dmenu
x11-misc/slock
x11-misc/slstatus
x11-misc/tabbed
x11-terms/st
www-client/surf

# X11 tools
x11-misc/unclutter
x11-misc/wmname
x11-misc/xssstate
x11-apps/setxkbmap
x11-apps/xbacklight
x11-apps/xev
x11-apps/xmodmap
x11-apps/xrandr
x11-misc/xclip

# Misc
sys-apps/haveged
```

Before emerging, you have to add the `drkhsh` overlay (where `slstatus` resides).
Begin by installing `app-eselect/eselect-repository` and `dev-vcs/git` so you
can use third-party `git` overlays:
```
emerge -a app-eselect/eselect-repository dev-vcs/git
```

Then, add the `drkhsh` (and my own, heh) overlay:
```
eselect repository add drkhsh-overlay git https://github.com/drkhsh/overlay.git
eselect repository enable optmzr
```

Syncronize the overlays with Portage:
```
emerge --sync
```

And install all packages in the `@favorites` set with:
```
emerge -a @favorites
```
