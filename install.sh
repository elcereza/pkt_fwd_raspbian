#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/elcereza/LoRaWAN"
ENV_FILE="/etc/default/elcereza-lorawan"
SERVICE_NAME="elcereza-lorawan-sx1301.service"
LEGACY_SERVICE_NAME="elcereza.service"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
LEGACY_SERVICE_FILE="/etc/systemd/system/${LEGACY_SERVICE_NAME}"
REBOOT_REQUIRED=0

if [[ $EUID -ne 0 ]]; then
    exec sudo -E bash "$0" "$@"
fi

# shellcheck disable=SC1091
. "$SCRIPT_DIR/platform.sh"
detect_platform

banner() {
cat <<'BANNER'

                                %@@
                                @@   (@@@@@@@@@@@@@@@@@@
                               @ @@@@@@@@@@@@@@@@@@@@@@@@@@
                            @@@@@@@@@@@@@@@@@@@@@@@@@@@
                          @@ @@      &@@@@@@@@@@#
                        @@   .@
                       @/     @#
                      @,       @
                     @@         @/
                     @           @@
                     @             @@@@@&
                    @@@@#      @@@@@@@@@@@@@@
               &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
             *@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(
             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
             @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&
              &@@@@@@@@@@@@@@@   @@@@@@@@@@
                 @@@@@@@@@@

                        elcereza.com
               Gustavo Cereza  &  Adail Silva

BANNER
}

log() { echo "[install] $*"; }
die() { echo "[install] ERRO: $*" >&2; exit 1; }

set_kv() {
    local file="$1" key="$2" value="$3"
    touch "$file"
    sed -i -E "/^[[:space:]]*${key}=/d" "$file"
    printf '%s=%s\n' "$key" "$value" >> "$file"
}

append_armbian_overlay() {
    local file="$1" overlay="$2" current=""
    current="$(grep -E '^[[:space:]]*overlays=' "$file" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
    if ! grep -qw -- "$overlay" <<<"$current"; then
        current="${current:+$current }$overlay"
    fi
    set_kv "$file" overlays "$current"
}

configure_spi_raspberry() {
    log "Habilitando SPI no Raspberry Pi OS..."
    if command -v raspi-config >/dev/null 2>&1; then
        raspi-config nonint do_spi 0 || true
    else
        local cfg=""
        if [[ -f /boot/firmware/config.txt ]]; then cfg=/boot/firmware/config.txt; fi
        if [[ -z "$cfg" && -f /boot/config.txt ]]; then cfg=/boot/config.txt; fi
        [[ -n "$cfg" ]] || die "config.txt do Raspberry Pi não encontrado"
        sed -i -E 's/^[#[:space:]]*dtparam=spi=off/d' "$cfg"
        if ! grep -Eq '^[[:space:]]*dtparam=spi=on([[:space:]]|$)' "$cfg"; then
            printf '\n[all]\ndtparam=spi=on\n' >> "$cfg"
        fi
    fi
}

configure_spi_armbian() {
    local env=/boot/armbianEnv.txt bus=0 cs=0
    [[ -f "$env" ]] || die "Armbian detectado, mas $env não existe"
    if [[ "$SPI_DEV" =~ ^/dev/spidev([0-9]+)\.([0-9]+)$ ]]; then
        bus="${BASH_REMATCH[1]}"
        cs="${BASH_REMATCH[2]}"
    fi
    log "Habilitando SPI${bus}.${cs} pelo sistema de overlays do Armbian..."
    append_armbian_overlay "$env" spi-spidev
    set_kv "$env" param_spidev_spi_bus "$bus"
    set_kv "$env" param_spidev_spi_cs "$cs"
}

write_runtime_env() {
    mkdir -p /etc/default /etc/elcereza
    {
        echo '# Gerado automaticamente por lorawan-sx1301-packet-forwarder/install.sh'
        printf 'PLATFORM_FAMILY=%q\n' "$PLATFORM_FAMILY"
        printf 'BOARD_FAMILY=%q\n' "$BOARD_FAMILY"
        printf 'BOARD_MODEL=%q\n' "$BOARD_MODEL"
        printf 'SPI_DEV=%q\n' "$SPI_DEV"
        printf 'RESET_BCM=%q\n' "$RESET_BCM"
        printf 'GPIO_PROFILE=%q\n' "$GPIO_PROFILE"
        printf 'GPIO_CUSTOM_MAP=%q\n' "$GPIO_CUSTOM_MAP"
    } > "$ENV_FILE"
}

banner

echo "Plataforma detectada"
echo "--------------------"
print_platform_summary
echo

case "$PLATFORM_FAMILY" in
    raspberrypi|armbian) ;;
    *)
        die "plataforma não suportada automaticamente. Use Raspberry Pi OS ou Armbian."
        ;;
esac

case "$ARCH" in
    armhf|arm64) ;;
    *) die "arquitetura $ARCH não suportada para este gateway (esperado armhf ou arm64)." ;;
esac

[[ "$SPI_DEV" =~ ^/dev/spidev[0-9]+\.[0-9]+$ ]] || die "SPI_DEV inválido: $SPI_DEV"
[[ "$RESET_BCM" =~ ^[0-9]+$ ]] || die "RESET_BCM inválido: $RESET_BCM"

# GPIO numbers remain Raspberry Pi BCM on every SBC. Unknown hardware must have
# an explicit pinout profile; silently guessing a native GPIO can damage hardware.
GPIO_PROFILE="$GPIO_PROFILE" GPIO_CUSTOM_MAP="$GPIO_CUSTOM_MAP" bash "$SCRIPT_DIR/gpio-compat.sh" resolve "$RESET_BCM" >/dev/null || {
    die "SBC sem mapa GPIO Raspberry-compatível. Adicione /etc/elcereza/gpio-rpi-map.conf ou suporte o modelo em gpio-compat.sh."
}

log "Instalando dependências modernas do sistema..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    build-essential \
    git \
    ca-certificates \
    pkg-config \
    autoconf \
    automake \
    libtool \
    libtool-bin \
    file \
    gpiod

case "$PLATFORM_FAMILY" in
    raspberrypi) configure_spi_raspberry ;;
    armbian) configure_spi_armbian ;;
esac

if [[ ! -e "$SPI_DEV" ]]; then
    REBOOT_REQUIRED=1
fi

log "Preparando diretório de runtime sem apagar configuração existente..."
mkdir -p "$INSTALL_DIR"

# Preserve global_conf.json on reinstalls/upgrades.
if [[ ! -f "$INSTALL_DIR/global_conf.json" ]]; then
    install -m 0644 "$SCRIPT_DIR/global_conf.json" "$INSTALL_DIR/global_conf.json"
else
    log "global_conf.json existente preservado."
fi

install -m 0755 "$SCRIPT_DIR/start.sh" "$INSTALL_DIR/start.sh"
install -m 0755 "$SCRIPT_DIR/reset.sh" "$INSTALL_DIR/reset.sh"
install -m 0755 "$SCRIPT_DIR/gpio-compat.sh" "$INSTALL_DIR/gpio-compat.sh"
install -m 0755 "$SCRIPT_DIR/diagnose.sh" "$INSTALL_DIR/diagnose.sh"
install -m 0755 "$SCRIPT_DIR/build.sh" "$INSTALL_DIR/build.sh"
install -m 0755 "$SCRIPT_DIR/build-pi.sh" "$INSTALL_DIR/build-pi.sh"
install -m 0644 "$SCRIPT_DIR/platform.sh" "$INSTALL_DIR/platform.sh"

write_runtime_env

NEW_SERVICE_WAS_ACTIVE=0
LEGACY_SERVICE_WAS_ACTIVE=0

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    NEW_SERVICE_WAS_ACTIVE=1
    log "Parando $SERVICE_NAME durante a atualização..."
    systemctl stop "$SERVICE_NAME"
fi

if systemctl is-active --quiet "$LEGACY_SERVICE_NAME" 2>/dev/null; then
    LEGACY_SERVICE_WAS_ACTIVE=1
    log "Parando serviço legado $LEGACY_SERVICE_NAME durante a migração..."
    systemctl stop "$LEGACY_SERVICE_NAME"
fi

log "Compilando o packet forwarder nativamente para esta placa..."
if ! INSTALL_DIR="$INSTALL_DIR" "$INSTALL_DIR/build.sh"; then
    log "Build falhou; restaurando o serviço que estava ativo antes da tentativa."
    if [[ "$NEW_SERVICE_WAS_ACTIVE" -eq 1 ]]; then
        systemctl start "$SERVICE_NAME" 2>/dev/null || true
    fi
    if [[ "$LEGACY_SERVICE_WAS_ACTIVE" -eq 1 ]]; then
        systemctl start "$LEGACY_SERVICE_NAME" 2>/dev/null || true
    fi
    die "falha ao compilar o packet forwarder"
fi

log "Instalando serviço systemd $SERVICE_NAME..."
install -m 0644 "$SCRIPT_DIR/$SERVICE_NAME" "$SERVICE_FILE"

# Migração automática do nome histórico. Só removemos a unit antiga depois de
# um build bem-sucedido, para que uma falha de compilação nunca destrua uma
# instalação funcional existente.
if systemctl list-unit-files --type=service 2>/dev/null | awk '{print $1}' | grep -Fxq "$LEGACY_SERVICE_NAME" || [[ -e "$LEGACY_SERVICE_FILE" ]]; then
    log "Migrando $LEGACY_SERVICE_NAME -> $SERVICE_NAME..."
    systemctl disable --now "$LEGACY_SERVICE_NAME" 2>/dev/null || true
    rm -f "$LEGACY_SERVICE_FILE"
fi

systemctl daemon-reload
systemctl reset-failed "$LEGACY_SERVICE_NAME" 2>/dev/null || true
systemctl enable "$SERVICE_NAME"

if [[ "$REBOOT_REQUIRED" -eq 1 ]]; then
    log "SPI foi configurado, mas $SPI_DEV ainda não existe."
    log "A instalação terminou; reinicie o SBC para aplicar o overlay."
    log "Após o reboot, $SERVICE_NAME iniciará automaticamente."
else
    log "SPI já está disponível; iniciando $SERVICE_NAME..."
    systemctl restart "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "Gateway iniciado com sucesso."
    else
        systemctl status "$SERVICE_NAME" --no-pager || true
        die "o serviço foi instalado, mas não permaneceu ativo. Rode $INSTALL_DIR/diagnose.sh"
    fi
fi

echo
echo "Instalação concluída."
echo "Configuração : $INSTALL_DIR/global_conf.json"
echo "Diagnóstico  : sudo $INSTALL_DIR/diagnose.sh"
echo "Serviço      : $SERVICE_NAME"
echo "Logs         : sudo journalctl -u $SERVICE_NAME -f"
if [[ "$REBOOT_REQUIRED" -eq 1 ]]; then
    echo "Próximo passo: sudo reboot"
fi
