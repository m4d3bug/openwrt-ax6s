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

# Remove incompatible Go packages from passwall_packages
cd feeds/passwall_packages
for pkg in geoview shadowsocks-rust v2ray-plugin xray-plugin hysteria \
           naiveproxy shadow-tls tuic-client trojan-plus shadowsocksr-libev \
           v2ray-geodata; do
    [ -d "$pkg" ] && rm -rf "$pkg" && echo "Removed: $pkg"
done
cd ../..

# Remove geoview from passwall2 dependencies (it's a hard dep we can't build)
sed -i 's/+geoview//g' feeds/passwall2/luci-app-passwall2/Makefile
echo "=== passwall2 deps after patch ==="
grep "DEPENDS" feeds/passwall2/luci-app-passwall2/Makefile | head -5

echo "=== Remaining passwall packages ==="
ls feeds/passwall_packages/
