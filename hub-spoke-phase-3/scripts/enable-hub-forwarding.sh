#!/bin/bash
set -euo pipefail
# Temporary single-VM Linux router for an educational lab. Run as root via Azure Run Command.
# This is NOT a hardened production network appliance.
cat >/etc/sysctl.d/98-hubspoke-lab-forwarding.conf <<'SYSCTL'
net.ipv4.ip_forward = 1
SYSCTL
sysctl -p /etc/sysctl.d/98-hubspoke-lab-forwarding.conf

# Optional guest firewall allowance limited to this lab's two probe IPs.
# No SNAT: we want the receiving guest to see the original source IP.
if command -v iptables >/dev/null 2>&1; then
  iptables -C FORWARD -s 10.61.1.4/32 -d 10.62.1.4/32 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -s 10.61.1.4/32 -d 10.62.1.4/32 -j ACCEPT
  iptables -C FORWARD -s 10.62.1.4/32 -d 10.61.1.4/32 -j ACCEPT 2>/dev/null || \
    iptables -I FORWARD 1 -s 10.62.1.4/32 -d 10.61.1.4/32 -j ACCEPT
else
  echo 'NOTE: iptables not installed. Verify that Linux firewall policy permits the flow.'
fi
printf 'Kernel ip_forward: '; sysctl -n net.ipv4.ip_forward
printf 'Route to spoke1: '; ip route get 10.61.1.4
printf 'Route to spoke2: '; ip route get 10.62.1.4
echo 'Guest forwarding enabled. IPTables rules are not persisted across reboot; rerun this script if the VM restarts.'
