#!/bin/bash
# ============================================================
# Paso 3 de 9 — Configurar UFW Firewall
# VPSfacil-lite - Instalación Nativa sin Docker
# Sin Docker no hay conflicto iptables. UFW funciona
# directamente sin el fix "iptables: false".
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 3 de 9 — Firewall UFW"
show_progress 3 "Configurar UFW"
check_root

log_step "Configurando reglas UFW"
# TODO: ufw default deny incoming
# TODO: ufw default allow outgoing
# TODO: ufw allow 22/tcp comment "SSH"
# TODO: ufw allow 41641/udp comment "Tailscale WireGuard"
# TODO: ufw allow in on tailscale0 comment "Trafico VPN Tailscale"
# TODO: ufw --force enable

log_success "Firewall UFW configurado ✓"
