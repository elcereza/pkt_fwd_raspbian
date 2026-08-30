#!/usr/bin/env bash
# Compatibilidade com instalações/documentação antigas.
# O build agora é único para Raspberry Pi OS e Armbian.
exec "$(dirname "$0")/build.sh" "$@"
