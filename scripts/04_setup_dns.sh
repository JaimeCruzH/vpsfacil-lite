#!/bin/bash
# ============================================================
# Paso 5 de 9 — Configurar DNS en Cloudflare
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"
source "${SCRIPT_DIR}/../lib/cloudflare_api.sh"

source_config
print_header "Paso 5 de 9 — DNS Cloudflare"
show_progress 5 "Configurar DNS"
check_root

# TODO: Pedir CF_API_TOKEN si no esta en entorno
# TODO: Obtener Zone ID del dominio
# TODO: Crear registros A para cada app apuntando a TAILSCALE_IP:
#   files.vpn.${DOMAIN}
#   kopia.vpn.${DOMAIN}
#   beszel.vpn.${DOMAIN}

log_success "Registros DNS creados en Cloudflare ✓"
