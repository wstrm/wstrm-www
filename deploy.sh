#!/bin/bash

echo -e "\033[0;32mDeploying updates to git...\033[0m"

# Build the project.
hugo

# Add changes to git.
git add -A

# Commit changes.
msg="rebuilding site `date`"
if [ $# -eq 1 ]
  then msg="$1"
fi
git commit -m "$msg"

# Push source and build repos.
git push origin devel
git subtree push --prefix=public git@gitlab.com:willeponken/willeponken.gitlab.io.git master
