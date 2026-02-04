#!/system/bin/sh
# Docker & LXC Support Checker for Android GKI Kernel
# Run this script on your device to verify Docker/LXC support

echo "========================================"
echo "  Docker & LXC Support Checker"
echo "========================================"
echo ""

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "⚠️  Warning: Not running as root. Some checks may fail."
    echo ""
fi

# Function to check kernel config
check_config() {
    local config_name="$1"
    local description="$2"
    
    if zcat /proc/config.gz 2>/dev/null | grep -q "^${config_name}=y"; then
        echo "✅ ${description}"
        return 0
    elif zcat /proc/config.gz 2>/dev/null | grep -q "^${config_name}=m"; then
        echo "✅ ${description} (module)"
        return 0
    else
        echo "❌ ${description}"
        return 1
    fi
}

# Check if config.gz exists
if [ ! -f /proc/config.gz ]; then
    echo "❌ /proc/config.gz not found!"
    echo "   Cannot verify kernel configuration."
    echo ""
    echo "Trying alternative method..."
    if [ -f /boot/config-$(uname -r) ]; then
        echo "✅ Found config at /boot/config-$(uname -r)"
    else
        echo "❌ No kernel config available"
        exit 1
    fi
fi

echo "Kernel Version: $(uname -r)"
echo ""

# Namespaces
echo "📦 Namespace Support:"
check_config "CONFIG_NAMESPACES" "Namespaces"
check_config "CONFIG_NET_NS" "Network Namespace"
check_config "CONFIG_PID_NS" "PID Namespace"
check_config "CONFIG_IPC_NS" "IPC Namespace"
check_config "CONFIG_UTS_NS" "UTS Namespace"
echo ""

# Cgroups
echo "🔧 Cgroup Support:"
check_config "CONFIG_CGROUPS" "Cgroups"
check_config "CONFIG_CGROUP_CPUACCT" "CPU Accounting"
check_config "CONFIG_CGROUP_DEVICE" "Device Controller"
check_config "CONFIG_CGROUP_FREEZER" "Freezer"
check_config "CONFIG_CGROUP_SCHED" "Scheduler"
check_config "CONFIG_CPUSETS" "CPU Sets"
check_config "CONFIG_MEMCG" "Memory Controller"
echo ""

# Networking
echo "🌐 Network Support:"
check_config "CONFIG_VETH" "Virtual Ethernet"
check_config "CONFIG_BRIDGE" "Bridge"
check_config "CONFIG_BRIDGE_NETFILTER" "Bridge Netfilter"
check_config "CONFIG_IP_NF_NAT" "NAT"
check_config "CONFIG_IP_NF_TARGET_MASQUERADE" "Masquerade"
echo ""

# LXC Specific
echo "📦 LXC Specific:"
check_config "CONFIG_SYSVIPC" "System V IPC"
check_config "CONFIG_POSIX_MQUEUE" "POSIX Message Queue"
check_config "CONFIG_KEYS" "Key Management"
echo ""

# Filesystems
echo "💾 Filesystem Support:"
check_config "CONFIG_OVERLAY_FS" "OverlayFS"
check_config "CONFIG_EXT4_FS" "EXT4"
check_config "CONFIG_EXT4_FS_POSIX_ACL" "EXT4 POSIX ACL"
echo ""

# Summary
echo "========================================"
echo "  Summary"
echo "========================================"

TOTAL=0
PASSED=0

for config in CONFIG_NAMESPACES CONFIG_NET_NS CONFIG_PID_NS CONFIG_IPC_NS \
              CONFIG_CGROUPS CONFIG_CGROUP_DEVICE CONFIG_MEMCG \
              CONFIG_VETH CONFIG_BRIDGE CONFIG_OVERLAY_FS; do
    TOTAL=$((TOTAL + 1))
    if zcat /proc/config.gz 2>/dev/null | grep -q "^${config}=[ym]"; then
        PASSED=$((PASSED + 1))
    fi
done

echo "Passed: ${PASSED}/${TOTAL} critical checks"
echo ""

if [ "$PASSED" -eq "$TOTAL" ]; then
    echo "🎉 All critical features are enabled!"
    echo "   Docker and LXC should work properly."
elif [ "$PASSED" -ge $((TOTAL * 3 / 4)) ]; then
    echo "⚠️  Most features are enabled."
    echo "   Docker/LXC may work with limitations."
else
    echo "❌ Many features are missing."
    echo "   Docker/LXC will likely not work."
fi

echo ""
echo "========================================"
echo "  Additional Checks"
echo "========================================"

# Check for Docker
if command -v docker >/dev/null 2>&1; then
    echo "✅ Docker binary found"
    docker --version 2>/dev/null || echo "   (version check failed)"
else
    echo "ℹ️  Docker binary not found (install Docker to use)"
fi

# Check for LXC
if command -v lxc-checkconfig >/dev/null 2>&1; then
    echo "✅ LXC tools found"
    echo ""
    echo "Running lxc-checkconfig..."
    lxc-checkconfig 2>/dev/null || echo "   (lxc-checkconfig failed)"
else
    echo "ℹ️  LXC tools not found (install LXC to use)"
fi

echo ""
echo "========================================"
echo "  Done!"
echo "========================================"
