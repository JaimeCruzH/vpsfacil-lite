#!/bin/bash
# ============================================================
# lib/config.sh — Variables globales y configuración central
# VPSfacil-lite - Instalación Nativa sin Docker
#
# Sin Docker, sin Portainer — apps instaladas como servicios
# systemd directamente en el sistema.
#
# Orden de carga:
#   1. lib/colors.sh   → colores y print_header
#   2. lib/config.sh   → este archivo, variables globales
#   3. lib/utils.sh    → funciones que usan las variables
# ============================================================

# ============================================================
# FUNCIÓN PRINCIPAL: cargar o pedir configuración
# ============================================================
source_config() {
    if [[ -n "${DOMAIN:-}" && -n "${ADMIN_USER:-}" ]]; then
        _derive_config_vars
        return 0
    fi

    local config_file=""
    local candidates=(
        "${HOME}/setup.conf"
        "/tmp/vpsfacil_setup.conf"
        "/root/setup.conf"
    )
    if [[ -n "${SUDO_USER:-}" && -d "/home/${SUDO_USER}" ]]; then
        candidates+=("/home/${SUDO_USER}/setup.conf")
    fi

    for candidate in "${candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            config_file="$candidate"
            break
        fi
    done

    if [[ -n "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file"
        _derive_config_vars
        return 0
    fi

    echo ""
    echo -e "\033[1;31m[✗]\033[0m Error: No se encontró configuración guardada"
    echo -e "\033[0;34m[ℹ]\033[0m Ejecuta primero: bash setup.sh"
    echo ""
    exit 1
}

# ============================================================
# FUNCIÓN: solicitar configuración inicial al usuario
# ============================================================
ask_initial_config() {
    print_header "Configuración Inicial"

    log_info "Antes de instalar necesitamos dos datos básicos:"
    log_info "  1. Tu nombre de dominio (ej: miempresa.com)"
    log_info "  2. El nombre del usuario administrador a crear en el servidor"
    echo ""
    print_separator
    echo ""

    # --- Dominio ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 1 de 3 — Dominio${COLOR_RESET}"
    echo ""
    log_info "Escribe el nombre de tu dominio principal."
    log_info "Ejemplos: agentexperto.work  |  miempresa.com  |  startup.io"
    echo ""
    while true; do
        DOMAIN=$(prompt_input "¿Cuál es tu dominio?" "agentexperto.work")
        DOMAIN="${DOMAIN,,}"
        if [[ "$DOMAIN" =~ ^([a-z0-9][a-z0-9-]*\.)+[a-z]{2,}$ ]]; then
            break
        else
            log_warning "Formato inválido. Escribe solo el dominio, sin http ni www."
        fi
    done

    echo ""
    print_separator
    echo ""

    # --- Usuario admin ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 2 de 3 — Usuario administrador${COLOR_RESET}"
    echo ""
    log_info "Este usuario reemplazará a 'root' como administrador del servidor."
    log_info "Usa solo letras minúsculas, números y guión bajo (sin espacios)."
    echo ""
    while true; do
        ADMIN_USER=$(prompt_input "¿Qué nombre de usuario quieres crear?" "admin")
        ADMIN_USER="${ADMIN_USER,,}"
        if [[ "$ADMIN_USER" =~ ^[a-z][a-z0-9_]{1,31}$ ]]; then
            break
        else
            log_warning "Nombre inválido. Solo letras minúsculas, números y guión bajo."
        fi
    done

    echo ""
    print_separator
    echo ""

    # --- Zona horaria ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 3 de 3 — Zona horaria${COLOR_RESET}"
    echo ""
    log_info "Ejemplos: America/Santiago  |  America/Bogota  |  Europe/Madrid  |  UTC"
    echo ""
    TIMEZONE=$(prompt_input "¿Cuál es tu zona horaria?" "America/Santiago")
    echo ""

    # Confirmar configuración
    print_separator
    log_info "Resumen de configuración:"
    echo ""
    echo -e "   ${COLOR_BOLD_WHITE}Dominio:${COLOR_RESET}       ${COLOR_CYAN}${DOMAIN}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Usuario admin:${COLOR_RESET} ${COLOR_CYAN}${ADMIN_USER}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Zona horaria:${COLOR_RESET}  ${COLOR_CYAN}${TIMEZONE}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Home del usuario:${COLOR_RESET} ${COLOR_CYAN}/home/${ADMIN_USER}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Apps en:${COLOR_RESET}       ${COLOR_CYAN}/home/${ADMIN_USER}/apps${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}URL VPN base:${COLOR_RESET}  ${COLOR_CYAN}*.vpn.${DOMAIN}${COLOR_RESET}"
    echo ""
    print_separator

    if ! confirm "¿Es correcta esta configuración?"; then
        log_info "Volvamos a intentarlo..."
        ask_initial_config
        return
    fi

    _derive_config_vars
    save_config
}

# ============================================================
# FUNCIÓN: derivar variables a partir de DOMAIN y ADMIN_USER
# ============================================================
_derive_config_vars() {
    # Directorios base
    export ADMIN_HOME="/home/${ADMIN_USER}"
    export APPS_DIR="${ADMIN_HOME}/apps"
    export CERTS_DIR="${APPS_DIR}/certs"
    export BACKUP_DIR="${APPS_DIR}/backups"
    export LOG_DIR="/var/log/vpsfacil"

    # Subdominios VPN
    export VPN_SUBDOMAIN="vpn.${DOMAIN}"
    export CF_WILDCARD="*.vpn.${DOMAIN}"

    # URLs de aplicaciones (via Tailscale VPN)
    export URL_FILEBROWSER="https://files.vpn.${DOMAIN}"
    export URL_KOPIA="https://kopia.vpn.${DOMAIN}"
    export URL_BESZEL="https://beszel.vpn.${DOMAIN}"

    # Configuración de certificados
    export CERT_FILE="${CERTS_DIR}/origin-cert.pem"
    export CERT_KEY="${CERTS_DIR}/origin-cert-key.pem"
}

# ============================================================
# FUNCIÓN: guardar configuración en archivo
# ============================================================
save_config() {
    local config_file

    if [[ -d "/home/${ADMIN_USER}" ]]; then
        config_file="/home/${ADMIN_USER}/setup.conf"
    else
        config_file="/tmp/vpsfacil_setup.conf"
    fi

    cat > "$config_file" << EOF
# ============================================================
# VPSfacil-lite - Configuración de instalación
# Generado automáticamente el $(date '+%Y-%m-%d %H:%M:%S')
# ============================================================

DOMAIN="${DOMAIN}"
ADMIN_USER="${ADMIN_USER}"
TIMEZONE="${TIMEZONE:-America/Santiago}"
INSTALLATION_DATE="$(date '+%Y-%m-%d')"
EOF

    chmod 600 "$config_file"
    log_success "Configuración guardada en: ${config_file}"
}

# ============================================================
# VARIABLES DE CONFIGURACIÓN FIJA
# Sin Docker — apps corren como servicios systemd
# ============================================================

# Puertos de aplicaciones (HTTPS via nginx nativo)
readonly PORT_SSH="22"
readonly PORT_TAILSCALE="41641"
readonly PORT_NGINX="443"
readonly PORT_FILEBROWSER="8080"    # interno → nginx → 443
readonly PORT_KOPIA="51515"         # interno → nginx → 443
readonly PORT_BESZEL="8090"         # interno → nginx → 443

# Directorios de binarios instalados
readonly BIN_DIR="/usr/local/bin"
readonly SYSTEMD_DIR="/etc/systemd/system"
readonly NGINX_CONF_DIR="/etc/nginx/sites-available"
readonly NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"

# Timeouts (en segundos)
readonly TIMEOUT_SERVICE_START=30
readonly TIMEOUT_USER_INPUT=300
