#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="${INSTALL_DIR:-/elcereza/LoRaWAN}"
SRC_DIR="$INSTALL_DIR/dev"
ENV_FILE="/etc/default/elcereza-lorawan"
[[ -r "$ENV_FILE" ]] && . "$ENV_FILE"
SPI_DEV="${SPI_DEV:-/dev/spidev0.0}"

if [[ $EUID -ne 0 ]]; then
    echo "Execute este build como root (normalmente ele é chamado pelo install.sh)." >&2
    exit 1
fi

mem_kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
jobs="$(nproc 2>/dev/null || echo 1)"
if [[ "$mem_kb" -lt 750000 ]]; then
    jobs=1
elif [[ "$mem_kb" -lt 1500000 && "$jobs" -gt 2 ]]; then
    jobs=2
fi
JOBS="${BUILD_JOBS:-$jobs}"

log() { echo "[build] $*"; }

# Source lock: these are the revisions validated with this installer. The
# upstream projects are legacy and largely unmaintained; building arbitrary
# future HEADs would make field installations non-reproducible.
REV_LORA_GATEWAY="4d8f57f5d5cd021fda2ff67e41481f10f0c1b980"
REV_PAHO="e4e0402ae16985a1b83d77dab26e65532bed4174"
REV_TTN_CONNECTOR="10bfae4f8a8395b28180ca525e0dd29ae201543f"
REV_PROTOBUF_C="63c78ee066c72f0303294efa1ae971617876592d"
REV_PACKET_FORWARDER="14a54d54ce7526117512f178af1f0072d34e3415"

clone_pinned() {
    local url="$1" dir="$2" ref="$3"
    rm -rf "$SRC_DIR/$dir"
    # Full clone is intentional: it guarantees the locked commit can be
    # checked out even if the repository default branch moves later.
    git clone -q "$url" "$SRC_DIR/$dir"
    git -C "$SRC_DIR/$dir" checkout -q --detach "$ref"
    local got
    got="$(git -C "$SRC_DIR/$dir" rev-parse HEAD)"
    [[ "$got" == "$ref" ]] || {
        echo "[build] ERRO: revisão inesperada em $dir: $got" >&2
        return 1
    }
    log "$dir @ ${ref:0:12}"
}

mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

log "Clonando dependências de código-fonte em revisões fixadas..."
clone_pinned https://github.com/kersing/lora_gateway.git lora_gateway "$REV_LORA_GATEWAY"
clone_pinned https://github.com/kersing/paho.mqtt.embedded-c.git paho.mqtt.embedded-c "$REV_PAHO"
clone_pinned https://github.com/kersing/ttn-gateway-connector.git ttn-gateway-connector "$REV_TTN_CONNECTOR"
clone_pinned https://github.com/kersing/protobuf-c.git protobuf-c "$REV_PROTOBUF_C"
clone_pinned https://github.com/kersing/packet_forwarder.git packet_forwarder "$REV_PACKET_FORWARDER"

log "Configurando HAL LoRa para Linux native SPI em $SPI_DEV..."
cat > "$SRC_DIR/lora_gateway/libloragw/inc/imst_rpi.h" <<EOF2
#ifndef _IMST_RPI_H_
#define _IMST_RPI_H_
#define DISPLAY_PLATFORM "Radioenge + Linux SBC"
#define SPI_CS_CHANGE 0
#define VID 0x0403
#define PID 0x6014
#endif
EOF2

sed -i -E 's/^CFG_SPI=.*/CFG_SPI= native/' "$SRC_DIR/lora_gateway/libloragw/library.cfg"
sed -i -E 's/^PLATFORM=.*/PLATFORM= imst_rpi/' "$SRC_DIR/lora_gateway/libloragw/library.cfg"

log "Compilando HAL SX1301..."
make -C "$SRC_DIR/lora_gateway/libloragw" -j"$JOBS"

log "Compilando Paho MQTT Embedded C..."
make -C "$SRC_DIR/paho.mqtt.embedded-c" clean || true
make -C "$SRC_DIR/paho.mqtt.embedded-c" -j"$JOBS"

log "Compilando protobuf-c compatível com o connector legado..."
cd "$SRC_DIR/protobuf-c"
./autogen.sh
./configure --disable-protoc
make -j"$JOBS" protobuf-c/libprotobuf-c.la
mkdir -p "$SRC_DIR/protobuf-c/bin"
./libtool --mode=install /usr/bin/install -c protobuf-c/libprotobuf-c.la "$SRC_DIR/protobuf-c/bin"

log "Compilando TTN Gateway Connector..."
cp "$SRC_DIR/ttn-gateway-connector/config.mk.in" "$SRC_DIR/ttn-gateway-connector/config.mk"
make -C "$SRC_DIR/ttn-gateway-connector" clean >/dev/null 2>&1 || true
make -C "$SRC_DIR/ttn-gateway-connector" -j"$JOBS"

log "Aplicando compatibilidade do packet_forwarder legado com compiladores modernos..."
PF_DIR="$SRC_DIR/packet_forwarder/mp_pkt_fwd"
TRANSPORT_H="$PF_DIR/inc/transport.h"
TRANSPORT_C="$PF_DIR/src/transport.c"
STATS_C="$PF_DIR/src/stats.c"

# Upstream master (3.0.27) defines transport_status() without a declaration,
# while stats.c still calls transport_status(i). Old GCC accepted the implicit
# declaration/extra argument; GCC 14 correctly rejects both situations.
# The argument was never consumed by transport_status(), therefore normalize
# the API to a real no-argument function without changing runtime behaviour.
sed -i -E 's/transport_status[[:space:]]*\([[:space:]]*i[[:space:]]*\)[[:space:]]*;/transport_status();/' "$STATS_C"

if grep -qE '^[[:space:]]*void[[:space:]]+transport_status[[:space:]]*\([[:space:]]*void[[:space:]]*\)[[:space:]]*;' "$TRANSPORT_H"; then
    :
elif grep -qE '^[[:space:]]*void[[:space:]]+transport_status[[:space:]]*\(' "$TRANSPORT_H"; then
    sed -i -E 's/^[[:space:]]*void[[:space:]]+transport_status[[:space:]]*\([^;]*\)[[:space:]]*;/void transport_status(void);/' "$TRANSPORT_H"
else
    sed -i '/void transport_status_up/a void transport_status(void);' "$TRANSPORT_H"
fi

sed -i -E 's/^[[:space:]]*void[[:space:]]+transport_status[[:space:]]*\([[:space:]]*\)[[:space:]]*\{/void transport_status(void) {/' "$TRANSPORT_C"

# Assert the source patch before invoking make so failures are explicit.
grep -qF 'transport_status();' "$STATS_C" || { echo "[build] ERRO: não foi possível corrigir stats.c" >&2; exit 1; }
grep -qF 'void transport_status(void);' "$TRANSPORT_H" || { echo "[build] ERRO: protótipo transport_status ausente" >&2; exit 1; }
grep -qF 'void transport_status(void) {' "$TRANSPORT_C" || { echo "[build] ERRO: definição transport_status não normalizada" >&2; exit 1; }

log "Compilando mp_pkt_fwd nativamente para $(uname -m)..."
make -C "$SRC_DIR/packet_forwarder/mp_pkt_fwd" clean >/dev/null 2>&1 || true
make -C "$SRC_DIR/packet_forwarder/mp_pkt_fwd" -j"$JOBS" LGW_PATH="$SRC_DIR/lora_gateway/libloragw"

log "Build completo; instalando binário e bibliotecas de runtime..."
install -m 0644 "$SRC_DIR/paho.mqtt.embedded-c/build/output/libpaho-embed-mqtt3c.so.1.0" /usr/local/lib/libpaho-embed-mqtt3c.so.1.0
ln -sfn libpaho-embed-mqtt3c.so.1.0 /usr/local/lib/libpaho-embed-mqtt3c.so.1
ln -sfn libpaho-embed-mqtt3c.so.1 /usr/local/lib/libpaho-embed-mqtt3c.so

cd "$SRC_DIR/protobuf-c"
./libtool --mode=install /usr/bin/install -c protobuf-c/libprotobuf-c.la /usr/local/lib/

install -m 0755 "$SRC_DIR/ttn-gateway-connector/bin/libttn-gateway-connector.so" /usr/local/lib/libttn-gateway-connector.so
ldconfig

install -m 0755 "$SRC_DIR/packet_forwarder/mp_pkt_fwd/mp_pkt_fwd" "$INSTALL_DIR/mp_pkt_fwd"

log "Build concluído: $(file "$INSTALL_DIR/mp_pkt_fwd")"
