#!/bin/bash
# Flash firmware to Redmi AX6S via uboot web recovery
# Usage: ./scripts/flash-uboot.sh <firmware.bin> [eth_interface]
#
# Prerequisites:
#   1. AX6S is in uboot mode (hold RESET while powering on)
#   2. Wired ethernet connected to AX6S LAN port
#
# This script will:
#   - Configure the wired interface to 192.168.31.100
#   - Wait for uboot HTTP server at 192.168.31.1
#   - Upload firmware via HTTP POST

set -euo pipefail

FIRMWARE="${1:?Usage: $0 <firmware.bin> [eth_interface]}"
ETH="${2:-}"
ROUTER_IP="192.168.31.1"
HOST_IP="192.168.31.100"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

[ -f "$FIRMWARE" ] || error "Firmware file not found: $FIRMWARE"
[ "$(id -u)" -eq 0 ] || error "Must run as root (need to configure network interface)"

# Auto-detect wired interface if not specified
if [ -z "$ETH" ]; then
    # Find ethernet interfaces (not wireless, not loopback, not virtual)
    for iface in /sys/class/net/*/device; do
        iface="$(basename "$(dirname "$iface")")"
        if ! iw dev "$iface" info &>/dev/null 2>&1; then
            ETH="$iface"
            break
        fi
    done
    [ -n "$ETH" ] || error "Could not auto-detect wired ethernet interface. Specify as second argument."
fi

info "Using interface: $ETH"
info "Firmware: $FIRMWARE ($(du -h "$FIRMWARE" | cut -f1))"

# Configure interface
info "Setting $ETH to $HOST_IP/24..."
ip addr flush dev "$ETH" 2>/dev/null || true
ip addr add "$HOST_IP/24" dev "$ETH"
ip link set "$ETH" up

# Wait for uboot
info "Waiting for uboot at $ROUTER_IP ..."
info "(Power on AX6S while holding RESET button now)"
TIMEOUT=120
ELAPSED=0
while ! ping -c 1 -W 1 "$ROUTER_IP" &>/dev/null; do
    ELAPSED=$((ELAPSED + 1))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        error "Timeout waiting for uboot after ${TIMEOUT}s"
    fi
    printf "\r  Waiting... %ds" "$ELAPSED"
done
echo ""
info "uboot is responding!"

# Brief pause for HTTP server to be ready
sleep 2

# Try to detect uboot type and flash accordingly
# Method 1: Breed/Hanwckf uboot with web UI (HTTP upload)
info "Attempting HTTP upload to uboot web recovery..."

# Try common uboot web endpoints
UPLOADED=false
for endpoint in "/cgi-bin/firmware" "/cgi-bin/upload" "/"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 "http://$ROUTER_IP$endpoint" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" != "000" ] && [ "$HTTP_CODE" != "404" ]; then
        info "Found web interface at http://$ROUTER_IP$endpoint (HTTP $HTTP_CODE)"
        break
    fi
done

# Attempt upload - Breed uboot style
info "Uploading firmware..."
RESPONSE=$(curl -v --connect-timeout 10 --max-time 300 \
    -F "firmware=@$FIRMWARE" \
    "http://$ROUTER_IP/cgi-bin/firmware" 2>&1) && UPLOADED=true

if [ "$UPLOADED" = true ]; then
    info "Firmware uploaded successfully!"
    info "Router is flashing and will reboot automatically."
    info "DO NOT power off the router!"
    echo ""
    info "Waiting for router to come back online..."
    sleep 30

    TIMEOUT=180
    ELAPSED=0
    while ! ping -c 1 -W 1 "$ROUTER_IP" &>/dev/null; do
        ELAPSED=$((ELAPSED + 1))
        if [ $ELAPSED -ge $TIMEOUT ]; then
            warn "Router hasn't come back after ${TIMEOUT}s - this may be normal if LAN IP changed"
            break
        fi
        printf "\r  Waiting... %ds" "$ELAPSED"
    done
    echo ""
    info "Done! Try accessing http://192.168.31.1"
else
    warn "HTTP upload failed. Falling back to TFTP method..."
    echo ""
    info "=== TFTP Recovery ==="

    # Check for dnsmasq
    command -v dnsmasq >/dev/null || error "dnsmasq not installed. Install with: sudo dnf install dnsmasq"

    TFTP_DIR=$(mktemp -d)
    # Breed uboot expects filename matching hex IP of the client
    cp "$FIRMWARE" "$TFTP_DIR/C0A81F64.img"
    cp "$FIRMWARE" "$TFTP_DIR/firmware.bin"

    info "Starting TFTP server (files in $TFTP_DIR)..."
    info "Power cycle the router while holding RESET..."

    dnsmasq --no-daemon \
        --listen-address="$HOST_IP" \
        --bind-interfaces \
        --dhcp-range=192.168.31.50,192.168.31.99,255.255.255.0 \
        --enable-tftp \
        --tftp-root="$TFTP_DIR" \
        --dhcp-boot=C0A81F64.img \
        --port=0 \
        --log-dhcp \
        --bootp-dynamic \
        --no-ping

    rm -rf "$TFTP_DIR"
fi
