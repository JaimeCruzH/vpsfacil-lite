#!/bin/bash
# ============================================================
# Paso 1 de 9 — Verificaciones previas
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 1 de 9 — Verificaciones Previas"
show_progress 1 "Verificaciones previas"
check_root

log_step "Verificando sistema operativo"
# TODO: verificar Debian 12

log_step "Verificando conectividad a internet"
# TODO: ping/curl de prueba

log_step "Verificando espacio en disco"
# TODO: df -h, mínimo 5 GB libre

log_step "Instalando dependencias base"
# TODO: apt-get install -y curl wget gnupg2 ca-certificates lsb-release unzip jq python3 ufw fail2ban nginx

log_success "Verificaciones completadas ✓"
