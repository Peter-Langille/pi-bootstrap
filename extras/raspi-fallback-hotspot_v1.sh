#!/bin/bash

# raspi-fallback-hotspot_v1.sh
#
# Optional Raspberry Pi fallback Wi-Fi hotspot installer.
#
# PURPOSE
# -------
# Provides an SSH recovery path when a Raspberry Pi boots somewhere
# that none of its saved Wi-Fi networks are available.
#
# Normal boot:
#   Saved Wi-Fi available
#       -> NetworkManager connects normally
#       -> fallback hotspot is NOT started
#
# Recovery boot:
#   No saved Wi-Fi available
#       -> wait 30 seconds
#       -> start open Wi-Fi hotspot using the Pi hostname as the SSID
#       -> join that Wi-Fi
#       -> SSH using:
#
#          ssh <user>@<hostname>.local
#
# The hotspot remains active until the Pi is rebooted or another
# NetworkManager Wi-Fi connection is manually activated.
#
# REQUIREMENTS
# ------------
# - NetworkManager
# - nmcli
# - Wi-Fi interface wlan0 with AP support
# - avahi-daemon for hostname.local access
# - SSH server for remote access
#
# This installer intentionally does NOT modify existing saved Wi-Fi
# profiles and does NOT install itself into the core bootstrap.

set -euo pipefail

WIFI_DEVICE="wlan0"
HOTSPOT_PROFILE="fallback-hotspot"
WAIT_SECONDS="30"

HOSTNAME="$(hostname)"

FALLBACK_SCRIPT="/usr/local/sbin/fallback-hotspot.sh"
SYSTEMD_UNIT="/etc/systemd/system/fallback-hotspot.service"

echo
echo "============================================================"
echo " Raspberry Pi Fallback Hotspot Installer"
echo "============================================================"
echo
echo "Hostname:        ${HOSTNAME}"
echo "Wi-Fi device:    ${WIFI_DEVICE}"
echo "Hotspot SSID:    ${HOSTNAME}"
echo "Hotspot profile: ${HOTSPOT_PROFILE}"
echo "Fallback wait:   ${WAIT_SECONDS} seconds"
echo

# ------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------

if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: Run this installer with sudo."
    exit 1
fi

if ! command -v nmcli >/dev/null 2>&1; then
    echo "ERROR: nmcli was not found."
    echo "This setup requires NetworkManager."
    exit 1
fi

if ! systemctl list-unit-files NetworkManager.service \
    >/dev/null 2>&1; then
    echo "ERROR: NetworkManager.service was not found."
    exit 1
fi

if ! ip link show "${WIFI_DEVICE}" >/dev/null 2>&1; then
    echo "ERROR: Wi-Fi device ${WIFI_DEVICE} was not found."
    exit 1
fi

if ! command -v avahi-daemon >/dev/null 2>&1; then
    echo "ERROR: avahi-daemon was not found."
    echo "Install/configure Avahi before using this setup."
    exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
    echo "ERROR: sshd was not found."
    echo "Enable/install the SSH server before using this setup."
    exit 1
fi

echo "Preflight checks passed."

# ------------------------------------------------------------------
# Create/update NetworkManager fallback hotspot profile
# ------------------------------------------------------------------

echo
echo "Configuring NetworkManager hotspot profile..."

if nmcli -t -f NAME connection show | grep -Fxq "${HOTSPOT_PROFILE}"; then
    echo "Existing ${HOTSPOT_PROFILE} profile found."
else
    nmcli connection add \
        type wifi \
        ifname "${WIFI_DEVICE}" \
        con-name "${HOTSPOT_PROFILE}" \
        autoconnect no \
        ssid "${HOSTNAME}"
fi

nmcli connection modify "${HOTSPOT_PROFILE}" \
    connection.interface-name "${WIFI_DEVICE}" \
    connection.autoconnect no \
    802-11-wireless.ssid "${HOSTNAME}" \
    802-11-wireless.mode ap \
    802-11-wireless.band bg \
    ipv4.method shared \
    ipv6.method disabled

# Ensure the hotspot is genuinely open.
#
# Removing the complete wireless-security setting avoids creating
# a WEP-style security section with key-mgmt=none.
nmcli connection modify "${HOTSPOT_PROFILE}" \
    remove 802-11-wireless-security 2>/dev/null || true

echo "Hotspot profile configured."

# ------------------------------------------------------------------
# Install boot-time decision script
# ------------------------------------------------------------------

echo
echo "Installing ${FALLBACK_SCRIPT}..."

cat > "${FALLBACK_SCRIPT}" <<EOF
#!/bin/bash

# Raspberry Pi fallback Wi-Fi hotspot
#
# At boot:
#   1. Give NetworkManager time to connect to a saved Wi-Fi network.
#   2. Check whether ${WIFI_DEVICE} has an active infrastructure Wi-Fi connection.
#   3. If yes, leave it alone.
#   4. If not, activate the preconfigured ${HOTSPOT_PROFILE} profile.
#
# Once the hotspot starts, this script exits.
# It does NOT periodically attempt to replace the hotspot.

set -u

WIFI_DEVICE="${WIFI_DEVICE}"
HOTSPOT_PROFILE="${HOTSPOT_PROFILE}"
WAIT_SECONDS=${WAIT_SECONDS}

echo "Waiting \${WAIT_SECONDS} seconds for normal Wi-Fi..."
sleep "\${WAIT_SECONDS}"

ACTIVE_CONNECTION="\$(
    nmcli -g GENERAL.CONNECTION device show "\${WIFI_DEVICE}"
)"

if [[ -n "\${ACTIVE_CONNECTION}" && "\${ACTIVE_CONNECTION}" != "--" ]]; then

    WIFI_MODE="\$(
        nmcli -g 802-11-wireless.mode connection show "\${ACTIVE_CONNECTION}" 2>/dev/null
    )"

    if [[ "\${WIFI_MODE}" == "infrastructure" ]]; then
        echo "Infrastructure Wi-Fi is active: \${ACTIVE_CONNECTION}"
        echo "Fallback hotspot not required."
        exit 0
    fi
fi

echo "No active infrastructure Wi-Fi detected."
echo "Starting fallback hotspot..."

nmcli connection up "\${HOTSPOT_PROFILE}"

exit \$?
EOF

chmod 755 "${FALLBACK_SCRIPT}"

# ------------------------------------------------------------------
# Install systemd service
# ------------------------------------------------------------------

echo
echo "Installing ${SYSTEMD_UNIT}..."

cat > "${SYSTEMD_UNIT}" <<EOF
[Unit]
Description=Start fallback Wi-Fi hotspot when normal Wi-Fi is unavailable
Wants=NetworkManager.service
After=NetworkManager.service

[Service]
Type=oneshot
ExecStart=${FALLBACK_SCRIPT}

[Install]
WantedBy=multi-user.target
EOF

# ------------------------------------------------------------------
# Validate and enable
# ------------------------------------------------------------------

echo
echo "Validating systemd unit..."

systemctl daemon-reload
systemd-analyze verify "${SYSTEMD_UNIT}"

echo
echo "Enabling fallback hotspot service..."

systemctl enable fallback-hotspot.service

echo
echo "============================================================"
echo " Installation complete"
echo "============================================================"
echo
echo "Normal Wi-Fi has NOT been disconnected."
echo "The fallback service has NOT been started manually."
echo
echo "On future boots:"
echo
echo "  Normal saved Wi-Fi available:"
echo "      NetworkManager connects normally."
echo
echo "  No saved Wi-Fi available:"
echo "      After approximately ${WAIT_SECONDS} seconds,"
echo "      Wi-Fi SSID '${HOSTNAME}' will appear."
echo
echo "      Join it and SSH to:"
echo
echo "      ssh <user>@${HOSTNAME}.local"
echo
echo "To manually return to a saved Wi-Fi profile:"
echo
echo "      sudo nmcli connection up \"<profile-name>\""
echo
