#!/bin/bash
set -euo pipefail

ansible-pull -U https://github.com/thadigus/dotfiles.git ansible_pull.yml
