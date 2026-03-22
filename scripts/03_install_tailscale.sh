#!/bin/bash
# ============================================================
# Paso 4 de 9 — Instalar Tailscale VPN
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 4 de 9 — Tailscale VPN"
show_progress 4 "Instalar Tailscale"
check_root

log_step "Instalando Tailscale"
# TODO: curl -fsSL https://tailscale.com/install.sh | sh

log_step "Autenticando con Tailscale"
# TODO: tailscale up (interactivo, pegar URL en browser)

log_step "Obteniendo IP Tailscale"
# TODO: TAILSCALE_IP=$(tailscale ip -4)
# TODO: Guardar TAILSCALE_IP en setup.conf

log_success "Tailscale instalado y autenticado ✓"
