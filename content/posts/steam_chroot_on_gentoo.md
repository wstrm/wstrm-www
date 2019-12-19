---
title: "Steam Chroot on Gentoo"
date: 2019-05-29T09:42:14+02:00
description: "Running Steam inside a Gentoo chroot on... Gentoo."
draft: true
---

```
mkdir /usr/local/steam
cd /usr/local/steam
links http://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64/
tar -xvpf stage3*
rm stage3*
cp -L /etc/resolv.conf etc
mkdir usr/portage
mkdir usr/src/linux
mount -R /dev dev
mount -R /sys sys
mount -t proc proc proc
mount -R /usr/portage usr/portage
mount -R -o ro /usr/src/linux usr/src/linux
mount -R /run run
chroot .
env-update && source /etc/profile
useradd -m -G audio,video steam

emerge dev-vcs/git -q
wget -P /etc/portage/repos.conf/ https://raw.githubusercontent.com/anyc/steam-overlay/master/steam-overlay.conf
emaint sync --repo steam-overlay
emerge -qa games-util/steam-launcher

# Nvidia
emerge -qa x11-drivers/nvidia-drivers

# Sound
emerge -qa media-libs/alsa-lib media-sound/alsa-utils
```

```
aplay -L
```

```
pcm.!spdif {
     type hw
     card 1
     device 1
}

pcm.!default {
     type plug
     slave {
           pcm "spdif"
     }
}
```

```
#!/bin/sh

# Modified version of the chroot wrapper script from:
# https://wiki.gentoo.org/wiki/Steam#Chroot

# steam chroot bits
chroot_bits="64"

# steam chroot directory
chroot_dir="/usr/local/steam"

# check if chroot bits is valid
if [ "${chroot_bits}" = "32" ] ; then
  chroot_arch="linux32"
elif [ "${chroot_bits}" = "64" ] ; then
  chroot_arch="linux64"
else
  printf "Invalid chroot bits value '%s'. Permitted values are '32' or '64'.\n" "${chroot_bits}"
  exit 1
fi

# check if the chroot directory exists
if [ ! -d "${chroot_dir}" ] ; then
  printf "The chroot directory '%s' does not exist!\n" "${chroot_dir}"
  exit 1
fi

# mount the chroot directories
mount -v -t proc /proc "${chroot_dir}/proc"
mount -vR /sys "${chroot_dir}/sys"
mount -vR /dev "${chroot_dir}/dev"
mount -vR /run "${chroot_dir}/run"
mount -vR /usr/portage "${chroot_dir}/usr/portage"
mount -vR -o ro /usr/src/linux/ "${chroot_dir}/usr/src/linux"

# ensure that dbus and alsasound is running
rc-service dbus start
rc-service alsasound start

# chroot, substitute user, and start steam
"${chroot_arch}" chroot "${chroot_dir}" su -c 'steam' steam

# unmount the chroot directories when steam exits
umount -vl "${chroot_dir}/proc"
umount -vl "${chroot_dir}/sys"
umount -vl "${chroot_dir}/dev"
umount -vl "${chroot_dir}/run"
umount -vl "${chroot_dir}/usr/portage"
umount -vl "${chroot_dir}/usr/src/linux"
```

```
chmod +x /usr/local/bin/steam-chroot
```

```
emerge --ask --noreplace x11-apps/xhost
```

```
xhost +local:
```

Civilization 5
```
CFLAGS="-march=native -O1 -pipe" emerge -1 x11-libs/libxcb media-sound/pulseaudio sys-libs/glibc
```
```
[371471.978756] Civ5XP[2293]: segfault at 14 ip 000000000885bd5f sp 00000000882ff080 error 4
[371471.978762] Civ5XP[2292]: segfault at 0 ip 0000000008cd8534 sp 00000000e636afe0 error 4
[371471.978763]  in Civ5XP[8048000+22a7000]
[371471.978764]  in Civ5XP[8048000+22a7000]
[371471.978767] Code: 00 00 00 00 5b 81 c3 f2 ea 62 01 8b b4 24 88 00 00 00 8b bc 24 84 00 00 00 8b 94 24 80 00 00 00 0f b7 87 88 00 00 00 8b 4a 04 <8b>
2c 81 85 ed 0f 84 ef 00 00 00 8b 0a 8b 52 08 89 54 24 20 f3 0f
[371471.978768] Code: 44 24 20 c7 00 00 00 00 00 83 c4 0c 5e 5f 5b 5d c3 0f 0b 55 53 57 56 83 ec 0c e8 00 00 00 00 5b 8b 6c 24 2c 8b 44 24 24 8b 00 <8b>
70 14 8b 48 18 0f b7 d5 89 54 24 08 8d 14 11 8b 78 04 81 c3 ac
```
```
taskset -c 0-3 %command%
```
