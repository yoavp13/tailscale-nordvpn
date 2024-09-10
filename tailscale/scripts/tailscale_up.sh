#!/bin/sh

set -x

tailscaled &

sleep 10s
ps auxwwf

ip route del default
ip route add default via 10.1.1.3 dev eth0

if [ -n "$TAILSCALE_UP_AUTH_KEY" ]; then
  tailscale up --advertise-exit-node --auth-key $TAILSCALE_UP_AUTH_KEY
else
  tailscale up --advertise-exit-node
fi

apk add mtr curl

while [ 1 ]; do
  sleep 60
  date
done
