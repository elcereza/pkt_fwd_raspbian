#!/usr/bin/env bash
set -Eeuo pipefail
INSTALL_DIR="${INSTALL_DIR:-/elcereza/LoRaWAN}"
ENV_FILE="/etc/default/elcereza-lorawan"
[[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
RESET_BCM="${RESET_BCM:-7}"
# shellcheck disable=SC1091
. "$INSTALL_DIR/gpio-compat.sh"

echo "[lorawan-reset] Raspberry-compatible BCM${RESET_BCM}: $(resolve_gpio "$RESET_BCM")"
rpi_gpio_pulse "$RESET_BCM" 100 100
