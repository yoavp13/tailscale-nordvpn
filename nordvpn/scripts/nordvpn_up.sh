#!/bin/sh

set -x
#set -e

export PATH=/scripts:$PATH

RECONNECT_AFTER_HOURS=1
RECONNECT_AFTER_SECONDS=$(($RECONNECT_AFTER_HOURS * 60 * 60))

if [ -z "$NORDVPN_TOKEN" ]; then
  echo "NORDVPN_TOKEN environment variable is unset."
  exit
fi

#update-alternatives --set iptables /usr/sbin/iptables-legacy

wait_for_nordvpn_daemon() {
  try=3
  while [ 1 ]; do
    nordvpn status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
      return 0
    fi
    sleep 3

    try=$(($try - 1))
    if [ $try -eq 0 ]; then
      /etc/init.d/nordvpn stop
      /etc/init.d/nordvpn start
      try=3
    fi

  done
}

nordvpn_connect() {
  try=3
  while [ 1 ]; do
    nordvpn connect --group ${NORDVPN_GROUP} ${NORDVPN_COUNTRY}
    if [ $? -eq 0 ]; then
      bash /scripts/iptables_rules.sh add
      return 0
    fi
    sleep 1

    try=$(($try - 1))
    if [ $try -eq 0 ]; then
      echo "Cannot connect to NordVPN. Try again later."
      sleep 3000
      exit 0
    fi
  done
}


env

/etc/init.d/nordvpn start
ps auxwwf

wait_for_nordvpn_daemon

# Turn off analytics
nordvpn set analytics off
nordvpn set notify off

nordvpn status

nordvpn account
if [ $? -eq 1 ]; then
  nordvpn login --token $NORDVPN_TOKEN
fi

nordvpn set protocol ${NORDVPN_OPENVPN_PROTOCOL:=tcp}
nordvpn set technology ${NORDVPN_TECHNOLOGY:=NordLynx}

# Our local subnet
nordvpn allowlist add subnet 10.1.1.0/24

# Enable the connection to persist through reboots
nordvpn set autoconnect p2p

# Enable the kill switch
nordvpn set killswitch on

nordvpn_connect

# Check the connection
nordvpn status

# Other options to consider:
# nordvpn set cybersec on
# nordvpn set obfuscate on
# nordvpn set notify on

echo "Reconnect period: ${RECONNECT_AFTER_SECONDS}s"

while [ 1 ]; do
  sleep $RECONNECT_AFTER_SECONDS
  echo "--- $(date +%Y%m%d_%H%M%S) ---"
  echo "Reconnecting to a different server and will reconnect after ${RECONNECT_AFTER_SECONDS}s"
  date
  nordvpn status
  nordvpn disconnect
  bash /scripts/iptables_rules.sh del
  sleep 1
  nordvpn_connect
  echo
done

