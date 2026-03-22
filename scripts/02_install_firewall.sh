#!/bin/bash
# ============================================================
# Paso 3 de 10 — Configurar UFW Firewall
# VPSfacil-lite - Instalación Nativa sin Docker
# Sin Docker no hay conflicto iptables. UFW funciona directo.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 3 de 10 — Firewall UFW"
show_progress 3 "Configurar firewall UFW"
check_root

# ── Configurar reglas UFW ──────────────────────────────────
log_step "Configurando reglas de firewall"

# Reset a estado limpio
ufw --force reset

# Políticas por defecto
ufw default deny incoming
ufw default allow outgoing
log_info "Políticas por defecto: denegar entrada, permitir salida"

# Permitir SSH (antes de activar el firewall)
ufw allow "${PORT_SSH}/tcp" comment "SSH"
log_success "SSH permitido en puerto ${PORT_SSH}/tcp ✓"

# Permitir tráfico WireGuard de Tailscale
ufw allow "${PORT_TAILSCALE}/udp" comment "Tailscale WireGuard"
log_success "Tailscale WireGuard permitido en puerto ${PORT_TAILSCALE}/udp ✓"

# Permitir todo el tráfico desde la interfaz Tailscale (VPN interna)
# Esto permitirá nginx, apps, etc. una vez que Tailscale esté activo
ufw allow in on tailscale0 comment "Trafico VPN Tailscale"
log_success "Tráfico interno VPN Tailscale permitido ✓"

# ── Activar UFW ────────────────────────────────────────────
log_step "Activando firewall"
ufw --force enable
log_success "Firewall UFW activado ✓"

# ── Mostrar estado ─────────────────────────────────────────
log_step "Estado del firewall"
ufw status verbose

log_success "Firewall UFW configurado ✓"
