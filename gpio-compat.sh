#!/usr/bin/env bash
# Raspberry Pi GPIO compatibility layer for Linux SBCs.
# Canonical API: GPIO numbers are ALWAYS Raspberry Pi BCM numbers.
# Board profiles translate BCM -> physical 40-pin header -> native GPIO.

set -Eeuo pipefail

GPIO_ENV_FILE="${GPIO_ENV_FILE:-/etc/default/elcereza-lorawan}"
[[ -r "$GPIO_ENV_FILE" ]] && . "$GPIO_ENV_FILE"

GPIO_PROFILE="${GPIO_PROFILE:-${BOARD_FAMILY:-auto}}"
GPIO_CUSTOM_MAP="${GPIO_CUSTOM_MAP:-/etc/elcereza/gpio-rpi-map.conf}"

# Canonical Raspberry Pi 40-pin header map: BCM -> physical pin.
rpi_bcm_to_physical() {
    case "$1" in
        2) echo 3;; 3) echo 5;; 4) echo 7;; 14) echo 8;; 15) echo 10;;
        17) echo 11;; 18) echo 12;; 27) echo 13;; 22) echo 15;; 23) echo 16;;
        24) echo 18;; 10) echo 19;; 9) echo 21;; 25) echo 22;; 11) echo 23;;
        8) echo 24;; 7) echo 26;; 0) echo 27;; 1) echo 28;; 5) echo 29;;
        6) echo 31;; 12) echo 32;; 13) echo 33;; 19) echo 35;; 16) echo 36;;
        26) echo 37;; 20) echo 38;; 21) echo 40;;
        *) return 1;;
    esac
}

# Return: backend|chip-role-or-chip|offset|native-name|physical-pin
# backend values: raspberry-bcm, gpiod
builtin_map() {
    local bcm="$1" phys
    phys="$(rpi_bcm_to_physical "$bcm")" || return 1

    case "$GPIO_PROFILE" in
        raspberry-pi|raspberrypi)
            printf 'raspberry-bcm||%s|BCM%s|%s\n' "$bcm" "$bcm" "$phys"
            ;;

        # BPI-M2 Zero / BPI-P2 Zero / BPI-M2+ use the same H3-style
        # Raspberry-compatible 40-pin header mapping documented by Banana Pi.
        bananapi-m2-zero|bananapi-p2-zero|bananapi-m2-plus|bananapi-h3-rpi40)
            case "$phys" in
                3)  echo 'gpiod|main|12|PA12|3';;
                5)  echo 'gpiod|main|11|PA11|5';;
                7)  echo 'gpiod|main|6|PA6|7';;
                8)  echo 'gpiod|main|13|PA13|8';;
                10) echo 'gpiod|main|14|PA14|10';;
                11) echo 'gpiod|main|1|PA1|11';;
                12) echo 'gpiod|main|16|PA16|12';;
                13) echo 'gpiod|main|0|PA0|13';;
                15) echo 'gpiod|main|3|PA3|15';;
                16) echo 'gpiod|main|15|PA15|16';;
                18) echo 'gpiod|main|68|PC4|18';;
                19) echo 'gpiod|main|64|PC0|19';;
                21) echo 'gpiod|main|65|PC1|21';;
                22) echo 'gpiod|main|2|PA2|22';;
                23) echo 'gpiod|main|66|PC2|23';;
                24) echo 'gpiod|main|67|PC3|24';;
                26) echo 'gpiod|main|71|PC7|26';;
                27) echo 'gpiod|main|19|PA19|27';;
                28) echo 'gpiod|main|18|PA18|28';;
                29) echo 'gpiod|main|7|PA7|29';;
                31) echo 'gpiod|main|8|PA8|31';;
                32) echo 'gpiod|rpio|2|PL2|32';;
                33) echo 'gpiod|main|9|PA9|33';;
                35) echo 'gpiod|main|10|PA10|35';;
                36) echo 'gpiod|rpio|4|PL4|36';;
                37) echo 'gpiod|main|17|PA17|37';;
                38) echo 'gpiod|main|21|PA21|38';;
                40) echo 'gpiod|main|20|PA20|40';;
                *) return 1;;
            esac
            ;;

        # Orange Pi PC / PC Plus H3 40-pin connector. GPIO numbering in the
        # vendor manual is the Allwinner native global line offset.
        orangepi-pc|orangepi-pc-plus|orangepi-h3-rpi40)
            case "$phys" in
                3)  echo 'gpiod|main|12|PA12|3';;
                5)  echo 'gpiod|main|11|PA11|5';;
                7)  echo 'gpiod|main|6|PA6|7';;
                8)  echo 'gpiod|main|13|PA13|8';;
                10) echo 'gpiod|main|14|PA14|10';;
                11) echo 'gpiod|main|1|PA1|11';;
                12) echo 'gpiod|main|110|PD14|12';;
                13) echo 'gpiod|main|0|PA0|13';;
                15) echo 'gpiod|main|3|PA3|15';;
                16) echo 'gpiod|main|68|PC4|16';;
                18) echo 'gpiod|main|71|PC7|18';;
                19) echo 'gpiod|main|64|PC0|19';;
                21) echo 'gpiod|main|65|PC1|21';;
                22) echo 'gpiod|main|2|PA2|22';;
                23) echo 'gpiod|main|66|PC2|23';;
                24) echo 'gpiod|main|67|PC3|24';;
                26) echo 'gpiod|main|21|PA21|26';;
                27) echo 'gpiod|main|19|PA19|27';;
                28) echo 'gpiod|main|18|PA18|28';;
                29) echo 'gpiod|main|7|PA7|29';;
                31) echo 'gpiod|main|8|PA8|31';;
                32) echo 'gpiod|main|200|PG8|32';;
                33) echo 'gpiod|main|9|PA9|33';;
                35) echo 'gpiod|main|10|PA10|35';;
                36) echo 'gpiod|main|201|PG9|36';;
                37) echo 'gpiod|main|20|PA20|37';;
                38) echo 'gpiod|main|198|PG6|38';;
                40) echo 'gpiod|main|199|PG7|40';;
                *) return 1;;
            esac
            ;;
        *) return 1;;
    esac
}

custom_map() {
    local bcm="$1" phys line
    [[ -r "$GPIO_CUSTOM_MAP" ]] || return 1
    phys="$(rpi_bcm_to_physical "$bcm")" || return 1
    # Format: BCM backend chip offset native_name physical_pin
    line="$(awk -v b="$bcm" '$1==b && $1 !~ /^#/ {print; exit}' "$GPIO_CUSTOM_MAP")"
    [[ -n "$line" ]] || return 1
    read -r _ backend chip offset native pin <<<"$line"
    [[ "${pin:-$phys}" == "$phys" ]] || {
        echo "GPIO map inválido: BCM$bcm deve corresponder ao pino físico $phys" >&2
        return 1
    }
    printf '%s|%s|%s|%s|%s\n' "$backend" "$chip" "$offset" "$native" "$phys"
}

resolve_gpio() {
    local bcm="$1"
    [[ "$bcm" =~ ^[0-9]+$ ]] || { echo "BCM inválido: $bcm" >&2; return 2; }
    rpi_bcm_to_physical "$bcm" >/dev/null || {
        echo "BCM$bcm não pertence ao conector Raspberry Pi de 40 pinos" >&2
        return 2
    }
    custom_map "$bcm" 2>/dev/null || builtin_map "$bcm" || {
        echo "Sem mapeamento GPIO para '$GPIO_PROFILE'." >&2
        echo "Não é seguro adivinhar pinout. Use GPIO_CUSTOM_MAP=$GPIO_CUSTOM_MAP com um perfil da placa." >&2
        return 3
    }
}

gpiodetect_lines() {
    command -v gpiodetect >/dev/null 2>&1 || return 1
    gpiodetect 2>/dev/null || true
}

resolve_chip_role() {
    local role="$1" detected name label
    [[ "$role" == gpiochip* ]] && { echo "$role"; return 0; }

    detected="$(gpiodetect_lines)"
    case "$role" in
        main)
            # Prefer the main pinctrl controller. On sunxi this is normally
            # gpiochip0; labels vary by kernel/device-tree generation.
            name="$(awk 'BEGIN{IGNORECASE=1} /pinctrl/ && $0 !~ /(r_pio|r-pio|rpio|1f02c00|7022000)/ {gsub(/\[/,"",$1); print $1; exit}' <<<"$detected")"
            [[ -n "$name" ]] || name="$(awk 'NR==1 {gsub(/\[/,"",$1); print $1}' <<<"$detected")"
            echo "${name:-gpiochip0}"
            ;;
        rpio)
            name="$(awk 'BEGIN{IGNORECASE=1} /(r_pio|r-pio|rpio|1f02c00|7022000)/ {gsub(/\[/,"",$1); print $1; exit}' <<<"$detected")"
            [[ -n "$name" ]] || name="gpiochip1"
            echo "$name"
            ;;
        *) echo "$role";;
    esac
}

gpioset_once() {
    local chip="$1" offset="$2" value="$3" hold_ms="${4:-0}" version major
    version="$(gpioset --version 2>/dev/null | head -n1 || true)"
    major="$(grep -oE '[0-9]+\.[0-9]+' <<<"$version" | head -n1 | cut -d. -f1 || true)"
    if [[ "${major:-1}" -ge 2 ]]; then
        if [[ "$hold_ms" -gt 0 ]]; then
            gpioset -c "$chip" -p "${hold_ms}ms" -t0 "${offset}=${value}"
        else
            gpioset -c "$chip" -t0 "${offset}=${value}"
        fi
    else
        if [[ "$hold_ms" -gt 0 ]]; then
            gpioset -m time -u "$((hold_ms * 1000))" "$chip" "${offset}=${value}"
        else
            gpioset -m time -u 1000 "$chip" "${offset}=${value}"
        fi
    fi
}

rpi_gpio_set() {
    local bcm="$1" value="$2" spec backend role offset native phys chip
    [[ "$value" == 0 || "$value" == 1 ]] || { echo "valor deve ser 0 ou 1" >&2; return 2; }
    spec="$(resolve_gpio "$bcm")" || return
    IFS='|' read -r backend role offset native phys <<<"$spec"
    case "$backend" in
        raspberry-bcm)
            if command -v pinctrl >/dev/null 2>&1; then
                [[ "$value" == 1 ]] && pinctrl set "$bcm" op dh || pinctrl set "$bcm" op dl
            elif command -v raspi-gpio >/dev/null 2>&1; then
                [[ "$value" == 1 ]] && raspi-gpio set "$bcm" op dh || raspi-gpio set "$bcm" op dl
            else
                echo "pinctrl/raspi-gpio não encontrado" >&2; return 1
            fi
            ;;
        gpiod)
            command -v gpioset >/dev/null 2>&1 || { echo "gpioset não encontrado" >&2; return 1; }
            chip="$(resolve_chip_role "$role")"
            gpioset_once "$chip" "$offset" "$value" 1
            ;;
        *) echo "backend GPIO desconhecido: $backend" >&2; return 1;;
    esac
}

rpi_gpio_pulse() {
    local bcm="$1" high_ms="${2:-100}" low_ms="${3:-100}" spec backend role offset native phys chip
    spec="$(resolve_gpio "$bcm")" || return
    IFS='|' read -r backend role offset native phys <<<"$spec"
    case "$backend" in
        raspberry-bcm)
            if command -v pinctrl >/dev/null 2>&1; then
                pinctrl set "$bcm" op dh; sleep "$(awk -v m="$high_ms" 'BEGIN{printf "%.3f",m/1000}')"
                pinctrl set "$bcm" op dl; sleep "$(awk -v m="$low_ms" 'BEGIN{printf "%.3f",m/1000}')"
                pinctrl set "$bcm" ip
            elif command -v raspi-gpio >/dev/null 2>&1; then
                raspi-gpio set "$bcm" op dh; sleep "$(awk -v m="$high_ms" 'BEGIN{printf "%.3f",m/1000}')"
                raspi-gpio set "$bcm" op dl; sleep "$(awk -v m="$low_ms" 'BEGIN{printf "%.3f",m/1000}')"
                raspi-gpio set "$bcm" ip
            else
                echo "pinctrl/raspi-gpio não encontrado" >&2; return 1
            fi
            ;;
        gpiod)
            command -v gpioset >/dev/null 2>&1 || { echo "gpioset não encontrado" >&2; return 1; }
            chip="$(resolve_chip_role "$role")"
            gpioset_once "$chip" "$offset" 1 "$high_ms"
            gpioset_once "$chip" "$offset" 0 "$low_ms"
            ;;
        *) return 1;;
    esac
}

print_map() {
    local bcm spec backend role offset native phys
    printf '%-5s %-5s %-18s %-12s %-9s\n' BCM PIN NATIVE CHIP OFFSET
    for bcm in 2 3 4 14 15 17 18 27 22 23 24 10 9 25 11 8 7 0 1 5 6 12 13 19 16 26 20 21; do
        if spec="$(resolve_gpio "$bcm" 2>/dev/null)"; then
            IFS='|' read -r backend role offset native phys <<<"$spec"
            if [[ "$backend" == raspberry-bcm ]]; then role="BCM"; fi
            printf '%-5s %-5s %-18s %-12s %-9s\n' "$bcm" "$phys" "$native" "$role" "$offset"
        fi
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    cmd="${1:-map}"
    case "$cmd" in
        resolve) resolve_gpio "${2:?Informe o BCM}";;
        set) rpi_gpio_set "${2:?Informe o BCM}" "${3:?Informe 0/1}";;
        pulse) rpi_gpio_pulse "${2:?Informe o BCM}" "${3:-100}" "${4:-100}";;
        map) print_map;;
        *) echo "Uso: $0 {map|resolve BCM|set BCM 0|1|pulse BCM [high_ms] [low_ms]}" >&2; exit 2;;
    esac
fi
