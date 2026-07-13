#!/bin/bash
set -euo pipefail
: "${MLX_PORT:=8080}"
: "${MLX_WG_PREFIX:=10.0.6.}"

get_wg_ip() { ifconfig 2>/dev/null | awk -v p="$MLX_WG_PREFIX" '$1=="inet" && index($2,p)==1 {print $2; exit}'; }

while :; do
  wg_ip="$(get_wg_ip)"
  if [ -n "$wg_ip" ]; then break; fi
  sleep 5
done

socat "TCP-LISTEN:${MLX_PORT},bind=${wg_ip},fork,reuseaddr" "TCP:127.0.0.1:${MLX_PORT}" &
br=$!
while kill -0 "$br" 2>/dev/null; do
  if [ "$(get_wg_ip)" != "$wg_ip" ]; then kill "$br" 2>/dev/null || true; break; fi
  sleep 15
done
wait "$br" 2>/dev/null || true
