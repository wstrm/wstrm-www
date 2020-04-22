---
title: "Upgrade Ubuntu Cosmic (18.10) to Focal (20.04)"
date: 2020-04-22T14:41:59+01:00
---

There is no supported upgrade path from Ubuntu Cosmic to the new Focal release.
I had an old server running Cosmic (that I picked 18.10 over 18.04 must surely
been an mistake). So let's upgrade Ubuntu to Focal the old school Debian way!

<!--more-->

Beware that this can potentially be a dangerous upgrade as it is not supported.
I had issues with SELinux refusing access to `systemctl` for root, but you can
read below how to fix it.

If you're feeling adventurous and comfortable with fixing any issue that could
arise, go ahead!

As root, replace all the occurrences of `cosmic` to `focal` in:

 * `/etc/apt/sources.list` and
 * `/etc/apt/sources.list.d`

The easiest way would be with `sed`:

```
sed -i 's/cosmic/focal/g' /etc/apt/sources.list
sed -i 's/cosmic/focal/g' /etc/apt/sources.list.d/*.list
```

*Tip: Double check that everything looks correct in these files.*

Before upgrading, update all the `apt` package sources:

```
apt update
```

Now, time for the scary part! Upgrade the system with:

```
apt -y dist-upgrade
```

---

During this upgrade, due to an update of SystemD, SELinux complains with
something along the line of:

```
Failed to execute operation: Access denied
```

When services are restarted.

This may sound crazy, but the easiest way is to send a `TERM` signal to PID 1
(SystemD's "system manager", or commonly known as `init`), which will tell the
process to reexecute itself:

```
kill -TERM 1
```

This is almost the same as running:

```
systemctl daemon-reexec
```

But SELinux didn't allow me to run that.

---

Tada! You should now have an upgraded system, you can verify it with:

```
lsb_release -a
```

Which should output:

```
Distributor ID: Ubuntu
Description:    Ubuntu 20.04 LTS
Release:        20.04
Codename:       focal
```

Woho! Long term support!

*PS: You have to reboot to use the latest kernel.*
