#!/bin/bash
set -euo pipefail
: "${COLIMA_CPU:=4}"
: "${COLIMA_MEMORY:=8}"
: "${COLIMA_DISK:=100}"

colima start --vm-type vz --cpu "$COLIMA_CPU" --memory "$COLIMA_MEMORY" --disk "$COLIMA_DISK" || true
launchctl setenv DOCKER_HOST "unix://$HOME/.colima/default/docker.sock"
