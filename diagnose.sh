#!/usr/bin/env bash
set -u

INSTALL_DIR="${INSTALL_DIR:-/elcereza/LoRaWAN}"
ENV_FILE="/etc/default/elcereza-lorawan"
SERVICE_NAME="elcereza-lorawan-sx1301.service"
LEGACY_SERVICE_NAME="elcereza.service"
[[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
SPI_DEV="${SPI_DEV:-/dev/spidev0.0}"

ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*"; }

echo "Radioenge LoRaWAN - diagnóstico"
echo "=============================="
echo "Modelo: $(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo desconhecido)"
echo "Kernel: $(uname -r)"
echo "Arquitetura: $(dpkg --print-architecture 2>/dev/null || uname -m)"
echo "SPI esperado: $SPI_DEV"
echo "GPIO profile: ${GPIO_PROFILE:-não configurado}"
echo "Reset canônico: BCM${RESET_BCM:-7}"
echo

[[ -e "$SPI_DEV" ]] && ok "$SPI_DEV disponível" || fail "$SPI_DEV ausente (pode ser necessário reiniciar após habilitar SPI)"
if [[ -x "$INSTALL_DIR/gpio-compat.sh" ]]; then
    if "$INSTALL_DIR/gpio-compat.sh" resolve "${RESET_BCM:-7}" >/tmp/lorawan-gpio-resolve.$$ 2>/dev/null; then
        ok "GPIO BCM${RESET_BCM:-7} -> $(cat /tmp/lorawan-gpio-resolve.$$)"
    else
        fail "sem tradução segura para BCM${RESET_BCM:-7}"
    fi
    rm -f /tmp/lorawan-gpio-resolve.$$
fi
[[ -x "$INSTALL_DIR/mp_pkt_fwd" ]] && ok "mp_pkt_fwd instalado" || fail "mp_pkt_fwd ausente"
ldconfig -p 2>/dev/null | grep -q 'libpaho-embed-mqtt3c' && ok "libpaho-embed-mqtt3c disponível" || fail "libpaho-embed-mqtt3c ausente"
ldconfig -p 2>/dev/null | grep -q 'libttn-gateway-connector' && ok "libttn-gateway-connector disponível" || fail "libttn-gateway-connector ausente"
ldconfig -p 2>/dev/null | grep -q 'libprotobuf-c' && ok "libprotobuf-c disponível" || fail "libprotobuf-c ausente"

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then ok "$SERVICE_NAME habilitado"; else warn "$SERVICE_NAME não habilitado"; fi
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then ok "$SERVICE_NAME ativo"; else warn "$SERVICE_NAME inativo"; fi
if systemctl list-unit-files --type=service 2>/dev/null | awk '{print $1}' | grep -Fxq "$LEGACY_SERVICE_NAME"; then warn "unit legada $LEGACY_SERVICE_NAME ainda presente"; else ok "unit legada removida"; fi

echo
echo "Últimas mensagens do serviço:"
journalctl -u "$SERVICE_NAME" -n 20 --no-pager 2>/dev/null || true
