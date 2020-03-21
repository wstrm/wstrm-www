---
title: "OOM killer bad"
date: 2020-03-21T09:46:45+01:00
---

Sometimes (read: always) the Linux OOM killer doesn't kill the offending
process. Usually, this is because as the system is out of memory, it isn't able
to do the memory intensive task of scanning through all the processes. Ironic.

I guess desktop-oriented distributions such as Ubuntu and Fedora tweaks the
OOM killer to not do this. More minimal (or meta) distributions like Arch Linux
and Gentoo doesn't touch these settings.

The fix is to simply tell the OOM killer to kill the offending process that
caused the out of memory situation, and not scan through all the processes.

There's a downside, and probably the reason to why it isn't enabled by default.
It is not necessarily the process that triggered the out of memory state that is
the actual offender. Suppose that `Process 1` has a memory leak and is gradually
increasing its memory usage. Then you start up `Process 2` that creates a high,
but temporary, memory spike. This would kill `Process 2` even though the _real_
offender is `Process 1`.

If you do not care about that downside, and just want to keep your computer
running instead of freezing, there's luckily a simple switch to change the
default behavior!

Just run:

```
sudo sysctl -w vm.oom_kill_allocating_task=1
```

Make it permanent by writing it to a file:

```
echo "vm.oom_kill_allocating_task = 1" \
    | sudo tee /etc/sysctl.d/55-oom-kill-allocating-task.conf
```

Done! Now you just have to keep your fingers crossed that it will kill the real
offender and not any innocent that is just passing by.
