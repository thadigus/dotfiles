#!/bin/bash
set -euo pipefail

ansible-pull -U https://git.turnerservices.cloud/thadigus/dotfiles.git ansible_pull.yml -K
