#!/bin/bash
# ============================================================
# Paso 1 de 10 — Verificaciones previas e instalación de dependencias
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 1 de 10 — Verificaciones Previas"
show_progress 1 "Verificaciones previas e instalación de dependencias"
check_root

# ── Verificar sistema operativo ────────────────────────────
log_step "Verificando sistema operativo"

if ! command_exists apt-get; then
    log_error "Este script requiere un sistema con apt (Debian/Ubuntu)."
    log_error "Instala en un sistema compatible e intenta de nuevo."
    exit 1
fi

if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    if [[ "${ID:-}" == "debian" && "${VERSION_ID:-}" == "12" ]]; then
        log_success "Sistema: Debian 12 (Bookworm) ✓"
    else
        log_warning "Sistema: ${PRETTY_NAME:-Linux}"
        log_warning "Este script fue desarrollado para Debian 12."
        log_warning "Puede funcionar en tu sistema pero no está garantizado."
    fi
else
    log_warning "No se pudo detectar la versión del sistema operativo."
    log_warning "Continuando de todas formas..."
fi

# ── Verificar conectividad a internet ──────────────────────
log_step "Verificando conectividad a internet"
check_internet

# ── Verificar espacio en disco ─────────────────────────────
log_step "Verificando espacio en disco"
DISK_AVAILABLE_GB=$(df -BG / | awk 'NR==2 {gsub("G",""); print $4}')
log_info "Espacio disponible en /: ${DISK_AVAILABLE_GB} GB"

if [[ "$DISK_AVAILABLE_GB" -lt 5 ]]; then
    log_error "Espacio insuficiente: ${DISK_AVAILABLE_GB} GB disponibles (mínimo 5 GB requeridos)."
    exit 1
fi
log_success "Espacio en disco suficiente: ${DISK_AVAILABLE_GB} GB disponibles ✓"

# ── Configurar zona horaria ────────────────────────────────
log_step "Configurando zona horaria"
if command_exists timedatectl; then
    timedatectl set-timezone "${TIMEZONE}" 2>/dev/null && \
        log_success "Zona horaria configurada: ${TIMEZONE}" || \
        log_warning "No se pudo configurar la zona horaria automáticamente."
fi

# ── Instalar dependencias base ─────────────────────────────
log_step "Instalando dependencias base"

wait_for_dpkg

log_process "Actualizando lista de paquetes..."
apt-get update -qq

log_process "Instalando paquetes necesarios..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl \
    wget \
    gnupg2 \
    ca-certificates \
    lsb-release \
    unzip \
    jq \
    ufw \
    fail2ban \
    nginx \
    certbot \
    python3-certbot-dns-cloudflare

# ── Verificar instalaciones críticas ──────────────────────
log_step "Verificando instalaciones"

for cmd in curl wget jq ufw nginx certbot; do
    if command_exists "$cmd"; then
        log_success "${cmd} instalado ✓"
    else
        log_error "${cmd} no se pudo instalar. Verifica tu conexión e intenta de nuevo."
        exit 1
    fi
done

# Detener nginx por ahora (lo configuraremos más adelante)
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true

log_success "Verificaciones previas completadas ✓"
