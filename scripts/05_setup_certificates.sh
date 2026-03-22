#!/bin/bash
# ============================================================
# Paso 6 de 10 — Certificados SSL wildcard con Let's Encrypt
# VPSfacil-lite - Instalación Nativa sin Docker
# Usa certbot con DNS-01 challenge vía Cloudflare API
# No requiere que nginx esté corriendo ni que el dominio
# sea accesible desde internet.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 6 de 10 — Certificados SSL"
show_progress 6 "Obtener certificado SSL wildcard"
check_root

# ── Verificar prerequisitos ────────────────────────────────
log_step "Verificando prerequisitos"

if ! command_exists certbot; then
    log_error "certbot no está instalado. Verifica que el paso 1 se completó correctamente."
    exit 1
fi

if [[ -z "${CF_API_TOKEN:-}" ]]; then
    log_error "CF_API_TOKEN no está configurado."
    exit 1
fi

log_success "certbot disponible ✓"

# ── Crear archivo de credenciales Cloudflare ───────────────
log_step "Configurando credenciales de Cloudflare para certbot"

CF_CREDENTIALS_DIR="/etc/cloudflare"
CF_CREDENTIALS_FILE="${CF_CREDENTIALS_DIR}/credentials.ini"

mkdir -p "${CF_CREDENTIALS_DIR}"
cat > "${CF_CREDENTIALS_FILE}" << EOF
# Cloudflare API credentials para certbot DNS-01 challenge
dns_cloudflare_api_token = ${CF_API_TOKEN}
EOF
chmod 600 "${CF_CREDENTIALS_FILE}"
log_success "Archivo de credenciales creado: ${CF_CREDENTIALS_FILE} ✓"

# ── Obtener certificado wildcard ───────────────────────────
log_step "Solicitando certificado wildcard a Let's Encrypt"
log_info "Dominio: *.${CERT_DOMAIN}"
log_info "Método: DNS-01 challenge via Cloudflare API"
log_info "Esto puede tardar 1-2 minutos mientras se verifica el dominio..."
echo ""

# Si el certificado ya existe y es válido, renovar en lugar de solicitar
CERT_DIR="/etc/letsencrypt/live/${CERT_DOMAIN}"

if [[ -f "${CERT_DIR}/fullchain.pem" ]]; then
    log_info "Ya existe un certificado para ${CERT_DOMAIN}. Verificando validez..."
    if certbot certificates --cert-name "${CERT_DOMAIN}" 2>/dev/null | grep -q "VALID"; then
        log_success "Certificado válido existente. No es necesario re-solicitarlo ✓"
    else
        log_process "Renovando certificado existente..."
        certbot renew --cert-name "${CERT_DOMAIN}" --quiet
    fi
else
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials "${CF_CREDENTIALS_FILE}" \
        --dns-cloudflare-propagation-seconds 30 \
        -d "*.${CERT_DOMAIN}" \
        --agree-tos \
        --email "admin@${DOMAIN}" \
        --non-interactive \
        --no-eff-email
fi

# ── Verificar que el certificado existe ───────────────────
log_step "Verificando certificado"

if [[ ! -f "${CERT_FILE}" ]]; then
    log_error "El certificado no se encontró en ${CERT_FILE}"
    log_error "Verifica que el dominio '${CERT_DOMAIN}' esté correctamente configurado en Cloudflare."
    exit 1
fi

if [[ ! -f "${CERT_KEY}" ]]; then
    log_error "La clave privada no se encontró en ${CERT_KEY}"
    exit 1
fi

log_success "Certificado SSL obtenido ✓"
log_info "Certificado: ${CERT_FILE}"
log_info "Clave:       ${CERT_KEY}"

# ── Configurar nginx snippet SSL ──────────────────────────
log_step "Configurando nginx con el certificado"

NGINX_SNIPPETS_DIR="/etc/nginx/snippets"
mkdir -p "${NGINX_SNIPPETS_DIR}"

cat > "${NGINX_SNIPPETS_DIR}/vpsfacil-ssl.conf" << EOF
# VPSfacil-lite SSL configuration
# Certificado wildcard Let's Encrypt para *.vpn.${DOMAIN}
ssl_certificate     ${CERT_FILE};
ssl_certificate_key ${CERT_KEY};
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;
EOF

log_success "Snippet SSL creado: ${NGINX_SNIPPETS_DIR}/vpsfacil-ssl.conf ✓"

# ── Crear configuración nginx base (redirect HTTP→HTTPS) ──
log_step "Configurando nginx (redirect HTTP a HTTPS)"

# Desactivar el sitio default de nginx
rm -f /etc/nginx/sites-enabled/default

# Crear redirect HTTP → HTTPS
cat > "/etc/nginx/sites-available/vpsfacil-redirect" << EOF
# VPSfacil-lite — Redirect HTTP a HTTPS
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOF

ln -sf /etc/nginx/sites-available/vpsfacil-redirect /etc/nginx/sites-enabled/vpsfacil-redirect

# ── Habilitar renovación automática ───────────────────────
log_step "Habilitando renovación automática de certificado"

# certbot instala automáticamente un timer systemd o cron job
if systemctl list-timers 2>/dev/null | grep -q certbot; then
    log_success "Timer de renovación automática activo ✓"
elif [[ -f /etc/cron.d/certbot ]]; then
    log_success "Cron job de renovación automática activo ✓"
else
    # Crear systemd timer manualmente si no existe
    systemctl enable certbot.timer 2>/dev/null && \
        systemctl start certbot.timer 2>/dev/null && \
        log_success "Timer de renovación activado ✓" || \
        log_warning "No se pudo activar el timer automático. Renueva manualmente con: certbot renew"
fi

# ── Iniciar nginx ──────────────────────────────────────────
log_step "Iniciando nginx"

nginx -t && \
    systemctl enable nginx && \
    systemctl start nginx && \
    log_success "nginx iniciado ✓" || \
    { log_error "nginx falló al iniciar. Verifica con: nginx -t"; exit 1; }

log_success "Certificado SSL wildcard configurado ✓"
