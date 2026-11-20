#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# SoulspireXI — Ubuntu LTS VPS Gateway Setup Script
#
# Installs WireGuard + nftables, enables IPv4 forwarding, configures sysctl
# hardening, and installs the WireGuard healthcheck systemd timer.
#
# Run as root on the Ubuntu LTS VPS ONLY after reviewing your VPS network
# interface name and placing /etc/wireguard/wg0.conf and /etc/nftables.conf.
###############################################################################

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Run as root (sudo $0)" >&2
    exit 1
fi

echo "==> Installing WireGuard, nftables, and network utilities..."
apt-get update
apt-get install -y --no-install-recommends wireguard nftables iproute2 curl dnsutils

echo "==> Enabling IPv4 packet forwarding & network tuning..."
cat <<'EOF' > /etc/sysctl.d/99-overlordsxi-gateway.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
sysctl --system

echo "==> Checking /etc/wireguard/wg0.conf..."
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "[WARN] /etc/wireguard/wg0.conf not found yet."
    echo "       Generate keys with: umask 077 && wg genkey | tee /etc/wireguard/vps.key | wg pubkey > /etc/wireguard/vps.pub"
    echo "       Populate from deploy/vps/wireguard/vps-wg0.conf.template, then run:"
    echo "       chmod 600 /etc/wireguard/wg0.conf && systemctl enable --now wg-quick@wg0"
else
    chmod 600 /etc/wireguard/wg0.conf
    systemctl enable --now wg-quick@wg0
fi

echo "==> Checking /etc/nftables.conf..."
if [ -f /etc/nftables.conf ]; then
    nft -c -f /etc/nftables.conf
    systemctl enable --now nftables
    nft -f /etc/nftables.conf
    echo "==> nftables rules validated and loaded."
else
    echo "[WARN] /etc/nftables.conf not found. Copy from deploy/vps/firewall/nftables-overlordsxi.conf.template first."
fi

echo "==> VPS gateway base setup complete."
