#!/bin/bash
# ============================================================
# VPSfacil-lite — Instalación Automatizada sin Docker
# https://github.com/JaimeCruzH/vpsfacil-lite
#
# Uso:
#   curl -sSL https://raw.githubusercontent.com/JaimeCruzH/vpsfacil-lite/main/setup.sh | bash
#   o descarga y ejecuta: bash setup.sh
#
# Requisitos:
#   - Linux con apt (recomendado: Debian 12)
#   - Acceso root
#   - Dominio con DNS en Cloudflare
# ============================================================
set -euo pipefail

# ── Directorio base del script ─────────────────────────────
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Cargar librerías ───────────────────────────────────────
source "${SETUP_DIR}/lib/colors.sh"
source "${SETUP_DIR}/lib/config.sh"
source "${SETUP_DIR}/lib/utils.sh"
source "${SETUP_DIR}/lib/progress.sh"

# ── Verificar root ─────────────────────────────────────────
check_root

# ── Banner ─────────────────────────────────────────────────
clear
echo ""
echo -e "${COLOR_BOLD_BLUE}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}                                                              ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN}VPSfacil-lite${COLOR_RESET} — Instalación Nativa sin Docker            ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_WHITE}Systemd · Nginx · Let's Encrypt · Tailscale VPN        ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}                                                              ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_BLUE}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""

# ── Configuración inicial ──────────────────────────────────
ask_initial_config

# ── Ejecutar pasos en orden ────────────────────────────────
STEPS=(
    "00_precheck.sh"
    "01_create_user.sh"
    "02_install_firewall.sh"
    "03_install_tailscale.sh"
    "04_setup_dns.sh"
    "05_setup_certificates.sh"
    "06_install_filebrowser.sh"
    "07_install_kopia.sh"
    "08_install_beszel.sh"
    "09_finalize.sh"
)

for script in "${STEPS[@]}"; do
    script_path="${SETUP_DIR}/scripts/${script}"
    if [[ ! -f "$script_path" ]]; then
        log_error "Script no encontrado: ${script_path}"
        exit 1
    fi
    bash "$script_path"
done

# ── Resumen final ──────────────────────────────────────────
echo ""
print_separator
echo ""
log_success "Instalación completa de VPSfacil-lite ✓"
echo ""
log_info "Aplicaciones disponibles (con Tailscale VPN activo):"
echo ""
echo -e "  ${COLOR_BOLD_WHITE}File Browser:${COLOR_RESET}  ${COLOR_CYAN}https://files.vpn.${DOMAIN}${COLOR_RESET}"
echo -e "  ${COLOR_BOLD_WHITE}Kopia Backup:${COLOR_RESET}  ${COLOR_CYAN}https://kopia.vpn.${DOMAIN}${COLOR_RESET}"
echo -e "  ${COLOR_BOLD_WHITE}Beszel:${COLOR_RESET}        ${COLOR_CYAN}https://beszel.vpn.${DOMAIN}${COLOR_RESET}"
echo ""
print_separator
