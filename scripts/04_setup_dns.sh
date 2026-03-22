#!/bin/bash
# ============================================================
# Paso 5 de 10 — Configurar registros DNS en Cloudflare
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
print_header "Paso 5 de 10 — DNS Cloudflare"
show_progress 5 "Configurar registros DNS"
check_root

# ── Verificar prerequisitos ────────────────────────────────
log_step "Verificando prerequisitos"

if [[ -z "${CF_API_TOKEN:-}" ]]; then
    log_error "CF_API_TOKEN no está configurado."
    log_error "Ejecuta setup.sh desde el principio para configurar las credenciales."
    exit 1
fi

if [[ -z "${TAILSCALE_IP:-}" ]]; then
    log_error "TAILSCALE_IP no está configurada."
    log_error "El paso de Tailscale (paso 4) debe completarse primero."
    exit 1
fi

log_success "CF_API_TOKEN: configurado ✓"
log_success "TAILSCALE_IP: ${TAILSCALE_IP} ✓"

# ── Obtener Zone ID ────────────────────────────────────────
log_step "Obteniendo Zone ID de Cloudflare"

ZONE_ID=$(cf_get_zone_id "${DOMAIN}")
if [[ -z "$ZONE_ID" ]]; then
    log_error "No se pudo obtener el Zone ID para '${DOMAIN}'."
    exit 1
fi

# ── Crear/Actualizar registros DNS ─────────────────────────
log_step "Creando registros DNS"
log_info "IP destino: ${TAILSCALE_IP} (Tailscale VPN)"
log_info "Todos los registros se crean sin proxy Cloudflare (DNS-only)"
echo ""

# File Browser
log_process "Configurando files.vpn.${DOMAIN}..."
cf_upsert_dns_record "${ZONE_ID}" "files.vpn.${DOMAIN}" "${TAILSCALE_IP}" "false"

# Kopia
log_process "Configurando kopia.vpn.${DOMAIN}..."
cf_upsert_dns_record "${ZONE_ID}" "kopia.vpn.${DOMAIN}" "${TAILSCALE_IP}" "false"

# Beszel
log_process "Configurando beszel.vpn.${DOMAIN}..."
cf_upsert_dns_record "${ZONE_ID}" "beszel.vpn.${DOMAIN}" "${TAILSCALE_IP}" "false"

# ── Resumen ────────────────────────────────────────────────
echo ""
log_step "Resumen de registros DNS creados"
echo ""
echo -e "   ${COLOR_BOLD_WHITE}files.vpn.${DOMAIN}${COLOR_RESET} → ${COLOR_CYAN}${TAILSCALE_IP}${COLOR_RESET}"
echo -e "   ${COLOR_BOLD_WHITE}kopia.vpn.${DOMAIN}${COLOR_RESET} → ${COLOR_CYAN}${TAILSCALE_IP}${COLOR_RESET}"
echo -e "   ${COLOR_BOLD_WHITE}beszel.vpn.${DOMAIN}${COLOR_RESET} → ${COLOR_CYAN}${TAILSCALE_IP}${COLOR_RESET}"
echo ""
log_info "Los registros DNS pueden tardar hasta 60 segundos en propagarse."

log_success "Registros DNS configurados en Cloudflare ✓"
