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

    log_info "Responde estas preguntas una sola vez. El resto de la instalación"
    log_info "fluye de forma automática (solo habrá una pausa en Tailscale)."
    echo ""
    print_separator
    echo ""

    # --- Dominio ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 1 de 5 — Dominio${COLOR_RESET}"
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
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 2 de 5 — Usuario administrador${COLOR_RESET}"
    echo ""
    log_info "Este usuario reemplazará a 'root' como administrador del servidor."
    log_info "También será tu usuario de acceso en File Browser, Kopia y Beszel."
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

    # --- Contraseña admin ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 3 de 5 — Contraseña de administrador${COLOR_RESET}"
    echo ""
    log_info "Esta contraseña se usará para:"
    log_info "  · El usuario Linux '${ADMIN_USER}' en el servidor"
    log_info "  · Login en File Browser, Kopia y Beszel"
    log_info "Requisitos: mínimo 12 caracteres, incluir mayúsculas, minúsculas y números."
    echo ""
    while true; do
        ADMIN_PASSWORD=$(prompt_password "Contraseña para '${ADMIN_USER}'")
        if [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
            log_error "Mínimo 12 caracteres. Intenta de nuevo."
            continue
        fi
        if ! echo "$ADMIN_PASSWORD" | grep -q '[A-Z]'; then
            log_error "Debe incluir al menos una letra mayúscula."
            continue
        fi
        if ! echo "$ADMIN_PASSWORD" | grep -q '[a-z]'; then
            log_error "Debe incluir al menos una letra minúscula."
            continue
        fi
        if ! echo "$ADMIN_PASSWORD" | grep -q '[0-9]'; then
            log_error "Debe incluir al menos un número."
            continue
        fi
        local pass_confirm
        pass_confirm=$(prompt_password "Confirma la contraseña")
        if [[ "$ADMIN_PASSWORD" != "$pass_confirm" ]]; then
            log_error "Las contraseñas no coinciden. Intenta de nuevo."
            continue
        fi
        log_success "Contraseña válida."
        break
    done

    echo ""
    print_separator
    echo ""

    # --- Zona horaria ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 4 de 5 — Zona horaria${COLOR_RESET}"
    echo ""
    log_info "Ejemplos: America/Santiago  |  America/Bogota  |  Europe/Madrid  |  UTC"
    echo ""
    TIMEZONE=$(prompt_input "¿Cuál es tu zona horaria?" "America/Santiago")
    echo ""

    print_separator
    echo ""

    # --- Cloudflare API Token ---
    echo -e "${COLOR_BOLD_WHITE}PREGUNTA 5 de 5 — Cloudflare API Token${COLOR_RESET}"
    echo ""
    log_info "Se usa para crear los registros DNS y para obtener el certificado SSL."
    log_info "Cómo obtenerlo:"
    log_info "  1. Ve a dash.cloudflare.com → My Profile → API Tokens"
    log_info "  2. Crea un token con permiso: Zone → DNS → Edit"
    log_info "  3. Copia y pega el token aquí"
    echo ""
    while true; do
        CF_API_TOKEN=$(prompt_input "Cloudflare API Token")
        if [[ -z "$CF_API_TOKEN" ]]; then
            log_error "El token no puede estar vacío."
            continue
        fi
        log_process "Verificando token con Cloudflare..."
        local cf_response
        cf_response=$(curl -sf -H "Authorization: Bearer ${CF_API_TOKEN}" \
            "https://api.cloudflare.com/client/v4/user/tokens/verify" 2>/dev/null || echo '{"success":false}')
        if echo "$cf_response" | grep -q '"success":true'; then
            log_success "Token de Cloudflare válido."
            break
        else
            log_error "Token inválido o sin permisos suficientes."
            log_info "Verifica que tenga el permiso Zone:DNS:Edit y vuelve a intentarlo."
        fi
    done

    echo ""

    # Confirmar configuración
    print_separator
    log_info "Resumen de configuración:"
    echo ""
    echo -e "   ${COLOR_BOLD_WHITE}Dominio:${COLOR_RESET}          ${COLOR_CYAN}${DOMAIN}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Usuario admin:${COLOR_RESET}    ${COLOR_CYAN}${ADMIN_USER}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Contraseña:${COLOR_RESET}       ${COLOR_CYAN}(configurada)${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Zona horaria:${COLOR_RESET}     ${COLOR_CYAN}${TIMEZONE}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}CF API Token:${COLOR_RESET}     ${COLOR_CYAN}(verificado ✓)${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Home del usuario:${COLOR_RESET} ${COLOR_CYAN}/home/${ADMIN_USER}${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}Apps en:${COLOR_RESET}          ${COLOR_CYAN}/home/${ADMIN_USER}/apps${COLOR_RESET}"
    echo -e "   ${COLOR_BOLD_WHITE}URLs VPN:${COLOR_RESET}         ${COLOR_CYAN}*.vpn.${DOMAIN}${COLOR_RESET}"
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

    # Configuración de certificados (Let's Encrypt via certbot)
    export CERT_FILE="/etc/letsencrypt/live/vpn.${DOMAIN}/fullchain.pem"
    export CERT_KEY="/etc/letsencrypt/live/vpn.${DOMAIN}/privkey.pem"
    export CERT_DOMAIN="vpn.${DOMAIN}"
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
ADMIN_PASSWORD="${ADMIN_PASSWORD}"
TIMEZONE="${TIMEZONE:-America/Santiago}"
CF_API_TOKEN="${CF_API_TOKEN}"
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
