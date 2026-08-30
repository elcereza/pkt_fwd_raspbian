#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for f in "$ROOT"/*.sh; do bash -n "$f"; done

# Repository identity must use the canonical name everywhere.
legacy_repo_name='pkt_fwd''_raspbian'
if grep -RniI --exclude=mp_pkt_fwd "$legacy_repo_name" "$ROOT" >/dev/null 2>&1; then
    echo "legacy repository name found" >&2
    exit 1
fi
grep -qF 'https://github.com/elcereza/lorawan-sx1301-packet-forwarder.git' "$ROOT/README.md"
! grep -q '^User=pi$' "$ROOT/elcereza-lorawan-sx1301.service"


# Canonical service name and safe migration from the historical unit.
grep -qF 'SERVICE_NAME="elcereza-lorawan-sx1301.service"' "$ROOT/install.sh"
grep -qF 'LEGACY_SERVICE_NAME="elcereza.service"' "$ROOT/install.sh"
grep -qF 'disable --now "$LEGACY_SERVICE_NAME"' "$ROOT/install.sh"
[[ -f "$ROOT/elcereza-lorawan-sx1301.service" ]]
[[ ! -e "$ROOT/elcereza.service" ]]
grep -qF 'Description=El Cereza LoRaWAN SX1301 Gateway' "$ROOT/elcereza-lorawan-sx1301.service"

# Canonical Raspberry BCM numbers must resolve to the same physical pins on all profiles.
declare -A expected=( [2]=3 [3]=5 [4]=7 [14]=8 [15]=10 [17]=11 [18]=12 [27]=13 [22]=15 [23]=16 [24]=18 [10]=19 [9]=21 [25]=22 [11]=23 [8]=24 [7]=26 [0]=27 [1]=28 [5]=29 [6]=31 [12]=32 [13]=33 [19]=35 [16]=36 [26]=37 [20]=38 [21]=40 )
for profile in raspberry-pi bananapi-m2-zero bananapi-p2-zero bananapi-m2-plus orangepi-pc orangepi-pc-plus; do
    for bcm in "${!expected[@]}"; do
        out="$(GPIO_PROFILE="$profile" GPIO_CUSTOM_MAP=/nonexistent "$ROOT/gpio-compat.sh" resolve "$bcm")"
        phys="${out##*|}"
        [[ "$phys" == "${expected[$bcm]}" ]] || { echo "$profile BCM$bcm mapped to physical $phys" >&2; exit 1; }
    done
done

# Critical original reset: BCM7 == physical pin 26.
[[ "$(GPIO_PROFILE=bananapi-m2-zero GPIO_CUSTOM_MAP=/nonexistent "$ROOT/gpio-compat.sh" resolve 7)" == 'gpiod|main|71|PC7|26' ]]
[[ "$(GPIO_PROFILE=orangepi-pc-plus GPIO_CUSTOM_MAP=/nonexistent "$ROOT/gpio-compat.sh" resolve 7)" == 'gpiod|main|21|PA21|26' ]]

# Build must normalize the legacy transport_status API exposed by GCC 14:
# stats.c calls transport_status(i), while transport.c ignores all arguments.
grep -qF "transport_status();" "$ROOT/build.sh"
grep -qF "void transport_status(void);" "$ROOT/build.sh"
grep -qF "void transport_status(void) {" "$ROOT/build.sh"

# Direct start path without hardware.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
: > "$tmp/spidev0.0"
cat > "$tmp/reset.sh" <<'X'; chmod +x "$tmp/reset.sh"
#!/bin/sh
exit 0
X
cat > "$tmp/mp_pkt_fwd" <<'X'; chmod +x "$tmp/mp_pkt_fwd"
#!/bin/sh
echo packet-forwarder-smoke-ok
X
out="$(INSTALL_DIR="$tmp" SPI_DEV="$tmp/spidev0.0" RESET_BCM=7 "$ROOT/start.sh")"
grep -q packet-forwarder-smoke-ok <<<"$out"

echo "smoke tests: OK"
