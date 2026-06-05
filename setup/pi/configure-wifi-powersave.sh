#!/bin/bash -eu

# Disable wifi power management on the client (station) interface when
# WIFI_POWER_SAVE_OFF=true. The brcmfmac driver enables power-save by default,
# which on a headless Pi can make the link flap or go sluggish — observed as
# archiving stalls and unresponsive SSH (issues #263, #654). configure-ap.sh
# already turns power-save off for the access-point case; this covers the
# common client-only setup. No-op unless the variable is set, so setup-teslausb
# calls it unconditionally.

function log_progress () {
  if declare -F setup_progress > /dev/null
  then
    setup_progress "configure-wifi-powersave: $1"
  else
    echo "configure-wifi-powersave: $1"
  fi
}

if [ "${WIFI_POWER_SAVE_OFF:-false}" != "true" ]
then
  exit 0
fi

if systemctl --quiet is-enabled NetworkManager.service
then
  # NetworkManager-native and persistent across reboots/reconnects.
  # wifi.powersave = 2 means "disable".
  mkdir -p /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/teslausb-wifi-powersave.conf <<EOF
[connection]
wifi.powersave = 2
EOF
  log_progress "wifi power-save disabled via NetworkManager drop-in"
else
  # Legacy wpa_supplicant/ifupdown path: an if-up.d hook re-applies it on every
  # interface bring-up so it survives reboots and reconnects.
  apt-get -y --force-yes install iw || true
  cat > /etc/network/if-up.d/teslausb-wifi-powersave <<'EOF'
#!/bin/bash
if [ "$IFACE" = "wlan0" ]
then
  iw dev wlan0 set power_save off || true
fi
EOF
  chmod a+x /etc/network/if-up.d/teslausb-wifi-powersave
  iw dev wlan0 set power_save off || true
  log_progress "wifi power-save disabled via if-up.d hook"
fi
