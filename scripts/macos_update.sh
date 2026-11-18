#!/bin/bash
set -euo pipefail

repo=https://git.turnerservices.cloud/thadigus/dotfiles.git

# At login this runs before the VPN/tailnet is up and the git host won't resolve.
# Wait up to 5 minutes for it; if it never comes up, ansible-pull reports the error.
for _ in $(seq 60); do
  curl -s -o /dev/null --max-time 5 "$repo" && break
  sleep 5
done

ansible-pull -U "$repo" ansible_pull.yml
brew update && brew upgrade
