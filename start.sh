#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="${INSTALL_DIR:-/elcereza/LoRaWAN}"
ENV_FILE="/etc/default/elcereza-lorawan"
[[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
SPI_DEV="${SPI_DEV:-/dev/spidev0.0}"

if [[ ! -e "$SPI_DEV" ]]; then
    echo "ERRO: interface SPI $SPI_DEV não existe." >&2
    echo "Execute: sudo /elcereza/LoRaWAN/diagnose.sh" >&2
    exit 1
fi

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "ERRO: o reset GPIO do concentrador requer privilégios de root. Use systemd ou sudo." >&2
    exit 1
fi

export LORAGW_SPI="$SPI_DEV"
"$INSTALL_DIR/reset.sh"
cd "$INSTALL_DIR"
exec ./mp_pkt_fwd
