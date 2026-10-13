# MSI keyboard backlight bridge for COSMIC

This installs a virtual Linux LED backed by `uleds` and connects its
brightness value to `msi-perkeyrgb`.

Brightness 0–255 is mapped to green RGB values:

- 0   → `000000` (off)
- 128 → `008000`
- 255 → `00ff00`

The bridge runs as a root systemd service because it needs access to
`/dev/uleds` and the MSI keyboard HID interface. COSMIC/UPower can then
control the virtual keyboard-backlight LED.

## Requirements

- `msi-perkeyrgb` installed and working with the keyboard
- A kernel with the `uleds` module available
- systemd

## Install

Run the installer:

    sudo ./install-msi-kbd-backlight.sh

It installs:

- `/usr/local/libexec/msi-uled-bridge.py`
- `/etc/systemd/system/msi-uled-bridge.service`
- `/etc/modules-load.d/uleds.conf`

The service loads `uleds`, registers `msi::kbd_backlight`, and starts at boot.

## Check status

    systemctl status msi-uled-bridge.service
    ls /sys/class/leds
    cat /sys/class/leds/msi::kbd_backlight/max_brightness
    cat /sys/class/leds/msi::kbd_backlight/brightness

The maximum brightness should be 255.

## Test

Set brightness through UPower:

    sudo busctl --system call org.freedesktop.UPower \
      /org/freedesktop/UPower/KbdBacklight \
      org.freedesktop.UPower.KbdBacklight SetBrightness i 128

Or write the LED value directly:

    echo 128 | sudo tee /sys/class/leds/msi::kbd_backlight/brightness

## Troubleshooting

View the service log:

    sudo journalctl -u msi-uled-bridge.service -b --no-pager

If the service reports that `/dev/uleds` is missing:

    sudo modprobe uleds
    sudo systemctl restart msi-uled-bridge.service

Only one process can own `/dev/uleds` at a time. Stop any manually
launched bridge before starting the systemd service.

If COSMIC shows an invalid percentage or does not control the LED,
check whether UPower exposes the backlight interface:

    busctl --system introspect org.freedesktop.UPower \
      /org/freedesktop/UPower/KbdBacklight

## Uninstall

    sudo systemctl disable --now msi-uled-bridge.service
    sudo rm -f /etc/systemd/system/msi-uled-bridge.service
    sudo rm -f /etc/modules-load.d/uleds.conf
    sudo rm -f /usr/local/libexec/msi-uled-bridge.py
    sudo systemctl daemon-reload

The virtual LED disappears when the bridge stops.
