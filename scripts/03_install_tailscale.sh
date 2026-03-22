#!/bin/bash
# ============================================================
# Paso 4 de 10 — Instalar Tailscale VPN
# VPSfacil-lite - Instalación Nativa sin Docker
# NOTA: Este paso tiene una pausa interactiva obligatoria.
#       El usuario debe autenticar en el browser de Tailscale.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 4 de 10 — Tailscale VPN"
show_progress 4 "Instalar y autenticar Tailscale VPN"
check_root

# ── Instalar Tailscale ─────────────────────────────────────
log_step "Instalando Tailscale"

if command_exists tailscale; then
    log_info "Tailscale ya está instalado. Verificando versión..."
    tailscale version
else
    log_process "Descargando e instalando Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    log_success "Tailscale instalado ✓"
fi

# Asegurar que el daemon esté corriendo
systemctl enable --now tailscaled
log_success "Daemon tailscaled activo ✓"

# ── Autenticar en Tailscale ────────────────────────────────
log_step "Autenticando con Tailscale"

# Verificar si ya está autenticado
if tailscale status 2>/dev/null | grep -q "^100\."; then
    log_info "Tailscale ya está autenticado."
else
    echo ""
    echo -e "${COLOR_BOLD_YELLOW}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD_YELLOW}║         ACCIÓN REQUERIDA: Autenticar en Tailscale            ║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_YELLOW}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_WHITE}Tailscale mostrará un link a continuación.${COLOR_RESET}"
    echo -e "${COLOR_WHITE}Debes abrir ese link en tu navegador para autorizar este servidor.${COLOR_RESET}"
    echo ""

    # Iniciar Tailscale — muestra el link de autenticación en pantalla
    tailscale up --accept-dns=false --hostname="vpsfacil-$(echo "${DOMAIN}" | tr '.' '-')" || true

    echo ""
    wait_for_user "Presiona Enter cuando hayas completado la autenticación en el browser..."

    # Verificar que la autenticación fue exitosa (hasta 60 segundos)
    log_process "Verificando autenticación..."
    AUTHENTICATED=false
    for i in $(seq 1 12); do
        if tailscale status 2>/dev/null | grep -q "^100\."; then
            AUTHENTICATED=true
            break
        fi
        log_process "Esperando autenticación... (${i}/12)"
        sleep 5
    done

    if [[ "$AUTHENTICATED" == "false" ]]; then
        log_error "No se pudo verificar la autenticación de Tailscale."
        log_error "Asegúrate de haber completado el proceso en el browser."
        log_info "Puedes intentar manualmente: tailscale up --accept-dns=false"
        exit 1
    fi
fi

log_success "Tailscale autenticado ✓"

# ── Obtener IP Tailscale ────────────────────────────────────
log_step "Obteniendo IP Tailscale"

TAILSCALE_IP=$(tailscale ip -4 2>/dev/null)

if [[ -z "$TAILSCALE_IP" ]]; then
    log_error "No se pudo obtener la IP de Tailscale."
    log_info "Verifica que Tailscale esté correctamente autenticado: tailscale status"
    exit 1
fi

log_success "IP Tailscale: ${TAILSCALE_IP}"

# ── Guardar IP en setup.conf ───────────────────────────────
log_step "Guardando configuración"

# Buscar el archivo de configuración guardado
CONF_FILE=""
for candidate in "${ADMIN_HOME}/setup.conf" "/tmp/vpsfacil_setup.conf" "/root/setup.conf"; do
    if [[ -f "$candidate" ]]; then
        CONF_FILE="$candidate"
        break
    fi
done

if [[ -z "$CONF_FILE" ]]; then
    log_error "No se encontró setup.conf para guardar la IP."
    exit 1
fi

# Agregar o actualizar TAILSCALE_IP en el archivo de configuración
if grep -q "^TAILSCALE_IP=" "$CONF_FILE"; then
    sed -i "s|^TAILSCALE_IP=.*|TAILSCALE_IP=\"${TAILSCALE_IP}\"|" "$CONF_FILE"
else
    echo "TAILSCALE_IP=\"${TAILSCALE_IP}\"" >> "$CONF_FILE"
fi

log_success "IP guardada en configuración ✓"
export TAILSCALE_IP

# ── Mostrar información ────────────────────────────────────
echo ""
log_info "Estado de Tailscale:"
tailscale status
echo ""
log_info "El servidor es accesible en la red VPN desde:"
echo -e "   ${COLOR_CYAN}${TAILSCALE_IP}${COLOR_RESET}"

log_success "Tailscale instalado y configurado ✓"
