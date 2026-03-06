#!/bin/bash
set -euo pipefail

# Flush existing rules
iptables -F
iptables -X

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow DNS (UDP 53)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT

# Allow SSH (port 22)
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Allow HTTP/HTTPS (ports 80/443)
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Allow communication with Docker host gateway
HOST_IP=$(ip route | grep default | cut -d" " -f3)
if [ -n "$HOST_IP" ]; then
    iptables -A INPUT -s "$HOST_IP" -j ACCEPT
    iptables -A OUTPUT -d "$HOST_IP" -j ACCEPT
fi

# Default: drop everything else
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Reject (not drop) remaining outbound for fast failure
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "Firewall configured: allowing DNS, SSH, HTTP/HTTPS; blocking all other traffic"

# Verify
if ! curl --connect-timeout 5 -s https://api.github.com/zen >/dev/null 2>&1; then
    echo "ERROR: Firewall verification failed - unable to reach https://api.github.com"
    exit 1
fi
echo "Firewall verification passed"
