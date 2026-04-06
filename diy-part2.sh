#!/bin/bash
# Customizations (runs AFTER feeds install)

cd "$(dirname "$0")/openwrt" 2>/dev/null || true

# Default LAN IP: 192.168.31.1 (match AX6S stock for uboot compat)
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# Hostname
sed -i 's/OpenWrt/AX6S/g' package/base-files/files/bin/config_generate

# Timezone: Asia/Shanghai
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "s|'UTC0'|'CST-8'|g" package/base-files/files/bin/config_generate
sed -i "s|zonename='UTC'|zonename='Asia/Shanghai'|g" package/base-files/files/bin/config_generate

# Set argon as default theme
sed -i 's/bootstrap/argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

# Remove problematic packages (toolchain incompatible)
rm -rf feeds/passwall_packages/geoview
rm -rf feeds/passwall_packages/shadowsocks-rust
