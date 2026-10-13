#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    echo "Run this installer with sudo: sudo $0" >&2
    exit 1
fi

MSI_BIN="$(command -v msi-perkeyrgb || true)"
if [[ -z "$MSI_BIN" ]]; then
    echo "Cannot find msi-perkeyrgb in PATH. Install it first, then rerun this script." >&2
    exit 1
fi

BRIDGE=/usr/local/libexec/msi-uled-bridge.py
UNIT=/etc/systemd/system/msi-uled-bridge.service

install -d -m 755 /usr/local/libexec

cat > "$BRIDGE" <<PYTHON
#!/usr/bin/python3
import struct
import subprocess

DEVICE = b"msi::kbd_backlight"
MSI = "$MSI_BIN"

# Register a virtual LED with a brightness range of 0–255.
registration = struct.pack("=64si", DEVICE, 255)

with open("/dev/uleds", "r+b", buffering=0) as led:
    led.write(registration)

    while True:
        data = led.read(4)
        if len(data) != 4:
            raise RuntimeError("Unexpected read from /dev/uleds")

        brightness = struct.unpack("=i", data)[0]
        brightness = max(0, min(255, brightness))
        color = f"00{brightness:02x}00"

        subprocess.run(
            [MSI, "--id", "1038:113a", "-s", color],
            check=True,
        )
PYTHON

chmod 755 "$BRIDGE"

cat > "$UNIT" <<'UNIT'
[Unit]
Description=Bridge virtual keyboard backlight to MSI keyboard RGB
After=systemd-modules-load.service
Before=upower.service

[Service]
Type=simple
ExecStartPre=/usr/bin/modprobe uleds
ExecStart=/usr/bin/python3 /usr/local/libexec/msi-uled-bridge.py
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT

echo uleds > /etc/modules-load.d/uleds.conf

systemctl daemon-reload
systemctl enable --now msi-uled-bridge.service

echo
echo "Installed. Service status:"
systemctl --no-pager --full status msi-uled-bridge.service || true
echo
echo "Virtual LED path: /sys/class/leds/msi::kbd_backlight"
