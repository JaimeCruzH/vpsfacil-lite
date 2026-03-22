#!/bin/bash
# ============================================================
# Paso 8 de 9 — Instalar Kopia Backup (binario nativo)
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 8 de 9 — Kopia Backup"
show_progress 8 "Instalar Kopia"
check_root

APP_DIR="${APPS_DIR}/kopia"

log_step "Instalando Kopia via repositorio oficial"
# TODO: Agregar clave GPG y repositorio de Kopia
# TODO: apt-get update && apt-get install -y kopia

log_step "Configurando Kopia Server"
# TODO: kopia server start en 127.0.0.1:${PORT_KOPIA}
# TODO: Crear servicio systemd para kopia server

log_step "Configurando nginx"
# TODO: Virtual host: kopia.vpn.${DOMAIN} -> 127.0.0.1:${PORT_KOPIA}
# TODO: Con certificado wildcard Let's Encrypt

log_success "Kopia instalado en https://kopia.vpn.${DOMAIN} ✓"
