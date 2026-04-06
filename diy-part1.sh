#!/bin/bash
# Add Passwall feeds (runs BEFORE feeds update)

cd "$(dirname "$0")/openwrt" 2>/dev/null || true

echo "src-git passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git;main" >> feeds.conf.default
echo "src-git passwall2 https://github.com/xiaorouji/openwrt-passwall2.git;main" >> feeds.conf.default

# Argon theme (clone directly into package tree, not via feeds)
git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

echo "=== feeds.conf.default ==="
cat feeds.conf.default
