---
title: "Ignore Git LFS for some remotes"
date: 2020-07-09T13:51:53+02:00
---

Here's a neat little snippet I wrote to ignore Git LFS for specific remotes.

<!--more-->

Just add this to `.git/hooks/pre-push` before the Git LFS hook:
```shell
#!/bin/sh

ignore_remotes="sr.ht gitlab.com"

echo "$ignore_remotes" | tr " " "\n" | while read -r remote; do
    if echo "$2" | grep -q "$remote" > /dev/null
    then
        echo "Skipping LFS push for $2"
        exit 0
    fi
done

... <git lfs hook here> ...

```

This will make sure that Git LFS isn't used for any of the remotes that match
the whitespace separated values in `$ignore_remotes`.

Enjoy!
