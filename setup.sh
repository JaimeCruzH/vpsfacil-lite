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

# ── Configuración inicial / Modo resume ───────────────────
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

# Buscar config en todas las ubicaciones posibles (compatibilidad con versiones anteriores)
_EXISTING_CONFIG=""
for _candidate in "/root/setup.conf" "/tmp/vpsfacil_setup.conf"; do
    if [[ -f "$_candidate" ]]; then
        _EXISTING_CONFIG="$_candidate"
        break
    fi
done
# También buscar en cualquier home de usuario
if [[ -z "$_EXISTING_CONFIG" ]]; then
    for _home in /home/*/; do
        if [[ -f "${_home}setup.conf" ]]; then
            _EXISTING_CONFIG="${_home}setup.conf"
            break
        fi
    done
fi

if [[ -n "$_EXISTING_CONFIG" ]]; then
    # ── Modo RESUME ─────────────────────────────────────────
    # setup.conf existe → el usuario ya ingresó sus datos en una sesión
    # anterior. Cargamos la configuración y mostramos el estado.
    echo -e "${COLOR_BOLD_YELLOW}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD_YELLOW}║         ↩  Retomando instalación anterior                    ║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_YELLOW}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    log_info "Configuración guardada encontrada en: ${_EXISTING_CONFIG}"
    log_info "No es necesario ingresar los datos de nuevo."
    source_config
    # Asegurar que también quede en /root/setup.conf para próximas ejecuciones
    [[ "$_EXISTING_CONFIG" != "/root/setup.conf" ]] && cp "$_EXISTING_CONFIG" /root/setup.conf && chmod 600 /root/setup.conf || true
    echo ""
    log_info "Configuración cargada:"
    echo -e "   ${COLOR_BOLD_WHITE}Dominio:${COLOR_RESET}       ${COLOR_CYAN}${DOMAIN}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Usuario admin:${COLOR_RESET} ${COLOR_CYAN}${ADMIN_USER}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Zona horaria:${COLOR_RESET}  ${COLOR_CYAN}${TIMEZONE}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}CF API Token:${COLOR_RESET}  ${COLOR_CYAN}(guardado ✓)${COLOR_RESET}"
    echo ""
    log_info "Estado de los pasos:"
    for script in "${STEPS[@]}"; do
        step_name="${script%.sh}"
        if step_is_done "${step_name}"; then
            echo -e "  ${COLOR_BOLD_GREEN}✓${COLOR_RESET}  ${step_name}"
        else
            echo -e "  ${COLOR_YELLOW}·${COLOR_RESET}  ${step_name} ${COLOR_YELLOW}(pendiente)${COLOR_RESET}"
        fi
    done
    echo ""
    log_info "Para empezar de cero: rm ${STATE_FILE} /root/setup.conf && bash setup.sh"
    echo ""
    wait_for_user "Presiona Enter para continuar..."
else
    # ── Instalación nueva ────────────────────────────────────
    ask_initial_config
fi

# ── Ejecutar pasos en orden (con checkpoint) ───────────────
for script in "${STEPS[@]}"; do
    step_name="${script%.sh}"
    script_path="${SETUP_DIR}/scripts/${script}"

    if step_is_done "${step_name}"; then
        echo -e "  ${COLOR_BOLD_GREEN}✓${COLOR_RESET}  ${COLOR_WHITE}${step_name}${COLOR_RESET} — ya completado, omitiendo"
        continue
    fi

    if [[ ! -f "$script_path" ]]; then
        log_error "Script no encontrado: ${script_path}"
        exit 1
    fi

    bash "$script_path"
    step_mark_done "${step_name}"
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
