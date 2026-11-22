#!/bin/bash
# ==============================================================================
# PF Firewall Isolation Management Script (macOS)
# Anchor: com.local.backend-isolation
# ==============================================================================
set -e

ANCHOR_NAME="com.local.backend-isolation"
RULE_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pf-backend-isolation.conf"

usage() {
    echo "Usage: sudo $0 {enable|disable|status|test}"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    enable)
        echo "[*] Validating PF rule syntax..."
        sudo pfctl -nf "$RULE_FILE"
        echo "[*] Loading rules into anchor '$ANCHOR_NAME'..."
        sudo pfctl -a "$ANCHOR_NAME" -f "$RULE_FILE"
        echo "[*] Enabling PF firewall..."
        sudo pfctl -e 2>/dev/null || true
        echo "[+] Anchor '$ANCHOR_NAME' loaded and active."
        ;;

    disable)
        echo "[*] Flushing rules from anchor '$ANCHOR_NAME'..."
        sudo pfctl -a "$ANCHOR_NAME" -F rules 2>/dev/null || true
        echo "[*] Disabling PF firewall..."
        sudo pfctl -d 2>/dev/null || true
        echo "[+] Firewall rules disabled and state restored."
        ;;

    status)
        echo "=== PF Info ==="
        sudo pfctl -s info
        echo ""
        echo "=== Rules in Anchor: $ANCHOR_NAME ==="
        sudo pfctl -a "$ANCHOR_NAME" -s rules
        ;;

    test)
        echo "[*] Checking local loopback access to Port 3001..."
        curl -I -s --connect-timeout 2 http://127.0.0.1:3001/ || echo "[!] Local loopback failed"
        echo "[*] Checking LAN IP access to Port 3001 (should fail if blocked)..."
        curl -I -s --connect-timeout 2 http://10.7.5.56:3001/ || echo "[+] Connection successfully blocked as expected"
        ;;

    *)
        usage
        ;;
esac
