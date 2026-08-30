#!/usr/bin/env bash

# Single platform detector. The application always speaks Raspberry Pi BCM GPIO;
# board-specific translation is handled by gpio-compat.sh.

detect_platform() {
    PLATFORM_FAMILY="unknown"
    BOARD_FAMILY="unknown"
    BOARD_MODEL="unknown"
    DISTRO_ID="unknown"
    DISTRO_VERSION="unknown"
    ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
    SPI_DEV="${LORAWAN_SPI_DEV:-/dev/spidev0.0}"
    RESET_BCM="${LORAWAN_RESET_BCM:-7}"

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_VERSION="${VERSION_ID:-unknown}"
    fi

    if [[ -r /proc/device-tree/model ]]; then
        BOARD_MODEL="$(tr -d '\0' </proc/device-tree/model 2>/dev/null || true)"
    elif [[ -r /sys/firmware/devicetree/base/model ]]; then
        BOARD_MODEL="$(tr -d '\0' </sys/firmware/devicetree/base/model 2>/dev/null || true)"
    fi

    if [[ -f /etc/armbian-release ]]; then
        PLATFORM_FAMILY="armbian"
    elif [[ "${DISTRO_ID,,}" == "raspbian" ]] || [[ "${BOARD_MODEL,,}" == *"raspberry pi"* ]]; then
        PLATFORM_FAMILY="raspberrypi"
    elif [[ "${ID_LIKE:-}" == *"debian"* ]] || [[ "${DISTRO_ID,,}" == "debian" ]]; then
        PLATFORM_FAMILY="debian"
    fi

    case "${BOARD_MODEL,,}" in
        *"banana pi m2 zero"*|*"bananapi m2 zero"*|*"bpi-m2 zero"*|*"bpi-m2-zero"*|*"m2-zero"*)
            BOARD_FAMILY="bananapi-m2-zero" ;;
        *"banana pi p2 zero"*|*"bpi-p2 zero"*|*"bpi-p2-zero"*)
            BOARD_FAMILY="bananapi-p2-zero" ;;
        *"banana pi m2 plus"*|*"bpi-m2+"*|*"bpi-m2 plus"*)
            BOARD_FAMILY="bananapi-m2-plus" ;;
        *"orange pi pc plus"*|*"orangepi pc plus"*)
            BOARD_FAMILY="orangepi-pc-plus" ;;
        *"orange pi pc"*|*"orangepi pc"*)
            BOARD_FAMILY="orangepi-pc" ;;
        *"raspberry pi"*)
            BOARD_FAMILY="raspberry-pi" ;;
        *)
            if [[ "$PLATFORM_FAMILY" == "armbian" ]]; then BOARD_FAMILY="armbian-generic"; else BOARD_FAMILY="generic"; fi ;;
    esac

    GPIO_PROFILE="${LORAWAN_GPIO_PROFILE:-$BOARD_FAMILY}"
    GPIO_CUSTOM_MAP="${LORAWAN_GPIO_MAP:-/etc/elcereza/gpio-rpi-map.conf}"

    export PLATFORM_FAMILY BOARD_FAMILY BOARD_MODEL DISTRO_ID DISTRO_VERSION ARCH
    export SPI_DEV RESET_BCM GPIO_PROFILE GPIO_CUSTOM_MAP
}

print_platform_summary() {
    printf '%-22s %s\n' "Sistema:" "$PLATFORM_FAMILY"
    printf '%-22s %s\n' "Distribuição:" "$DISTRO_ID $DISTRO_VERSION"
    printf '%-22s %s\n' "Arquitetura:" "$ARCH"
    printf '%-22s %s\n' "SBC:" "$BOARD_MODEL"
    printf '%-22s %s\n' "Perfil GPIO:" "$GPIO_PROFILE"
    printf '%-22s %s\n' "SPI:" "$SPI_DEV"
    printf '%-22s %s\n' "Reset canônico:" "BCM$RESET_BCM (pino físico 26 para BCM7)"
}
