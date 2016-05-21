---
title: "Gentoo with DM-Crypt LUKS (Work In Progress)"
date: "2016-05-21"
description: "Install Gentoo with DM-Crypt LUKS."
categories: 
    - "gentoo"
    - "os"
    - "encryption"
---

This article serves as somekind of meta instruction for installing Gentoo with DM-Crypt LUKS.

If this is your first time installing Gentoo it's probably a better idea to follow their tutorial on https:/wiki.gentoo.org/wiki/Handbook:AMD64/Full/Installation

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

## Prepare USB-key and filesystem

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
mkdir -v /tmp/efiboot
mount -v -t vfat /dev/sdY1 /tmp/efiboot
```

## Create Keyfile for LUKS
```
export GPG_TTY=$(tty)
dd if=/dev/urandom bs=8388607 count=1 | gpg --symmetric --cipher-algo AES256 --output /tmp/efiboot/<hostname>-luks-key.gpg
```

To be continued...
