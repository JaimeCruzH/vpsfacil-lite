#!/bin/bash
# ============================================================
# Paso 9 de 10 — Instalar Beszel Hub
# VPSfacil-lite - Instalación Nativa sin Docker
# Beszel Hub: interfaz web de monitoreo de servidores.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 9 de 10 — Beszel Hub"
show_progress 9 "Instalar Beszel Hub"
check_root

APP_DIR="${APPS_DIR}/beszel"

# ── Detectar arquitectura ──────────────────────────────────
log_step "Detectando arquitectura del sistema"

SYS_ARCH=$(uname -m)
case "$SYS_ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    armv7l)  ARCH="arm" ;;
    *)
        log_error "Arquitectura no soportada: ${SYS_ARCH}"
        exit 1
        ;;
esac
log_info "Arquitectura detectada: ${ARCH}"

# ── Descargar Beszel Hub ────────────────────────────────────
log_step "Descargando Beszel Hub desde GitHub"

BESZEL_HUB_BIN="${BIN_DIR}/beszel_hub"

if [[ -f "${BESZEL_HUB_BIN}" ]]; then
    log_info "Beszel Hub ya está instalado. Actualizando..."
fi

BESZEL_API_RESPONSE=$(curl -sf "https://api.github.com/repos/henrygd/beszel/releases/latest")

HUB_URL=$(echo "${BESZEL_API_RESPONSE}" \
    | jq -r --arg arch "${ARCH}" \
        '.assets[] | select((.name | ascii_downcase | contains("hub")) and (.name | contains($arch))) | .browser_download_url' \
    | head -1)

if [[ -z "$HUB_URL" ]]; then
    log_error "No se encontró el binario de Beszel Hub para ${ARCH}."
    log_info "Assets disponibles en este release:"
    echo "${BESZEL_API_RESPONSE}" | jq -r '.assets[].name' | while read -r name; do
        log_info "  - ${name}"
    done
    exit 1
fi

log_process "Descargando Hub: ${HUB_URL}"
TMPDIR_BZ=$(mktemp -d)
curl -fsSL "${HUB_URL}" -o "${TMPDIR_BZ}/beszel_hub.tar.gz"
tar -xzf "${TMPDIR_BZ}/beszel_hub.tar.gz" -C "${TMPDIR_BZ}"
install -m 755 "${TMPDIR_BZ}/beszel_hub" "${BESZEL_HUB_BIN}"
rm -rf "${TMPDIR_BZ}"
log_success "Beszel Hub instalado en ${BESZEL_HUB_BIN} ✓"

# ── Crear directorio de datos ──────────────────────────────
log_step "Configurando directorio de datos"

mkdir -p "${APP_DIR}"
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_DIR}"

# ── Crear servicio systemd para Hub ───────────────────────
log_step "Creando servicio systemd para Beszel Hub"

cat > "${SYSTEMD_DIR}/beszel.service" << EOF
[Unit]
Description=Beszel Hub - Monitoreo de servidores
After=network.target

[Service]
User=${ADMIN_USER}
Group=${ADMIN_USER}
WorkingDirectory=${APP_DIR}
ExecStart=${BESZEL_HUB_BIN} serve --http=127.0.0.1:${PORT_BESZEL}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable beszel
systemctl restart beszel

sleep 2
if ! systemctl is-active --quiet beszel; then
    log_error "El servicio beszel no pudo iniciarse."
    log_info "Revisa los logs con: journalctl -u beszel -n 30"
    exit 1
fi
log_success "Servicio beszel activado ✓"

# Esperar a que el Hub esté listo
wait_for_port "127.0.0.1" "${PORT_BESZEL}" "${TIMEOUT_SERVICE_START}"

# ── Crear usuario admin en Beszel ──────────────────────────
log_step "Creando usuario administrador en Beszel"

# Beszel usa PocketBase internamente. El primer admin se crea vía API.
# Esperamos un poco más para que PocketBase esté completamente listo.
sleep 3

ADMIN_EMAIL="${ADMIN_USER}@${DOMAIN}"

BESZEL_ADMIN_RESPONSE=$(curl -sf -X POST \
    "http://127.0.0.1:${PORT_BESZEL}/api/admins" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${ADMIN_EMAIL}\",\"password\":\"${ADMIN_PASSWORD}\",\"passwordConfirm\":\"${ADMIN_PASSWORD}\"}" \
    2>/dev/null || echo '{"error":""}')

if echo "${BESZEL_ADMIN_RESPONSE}" | grep -q '"id"'; then
    log_success "Usuario admin creado en Beszel ✓"
    log_info "  Email:    ${ADMIN_EMAIL}"
    log_info "  Password: (la que configuraste al inicio)"
elif echo "${BESZEL_ADMIN_RESPONSE}" | grep -qi "already.*exist\|unique constraint"; then
    log_info "El usuario admin ya existe en Beszel."
else
    log_warning "No se pudo crear el usuario admin automáticamente."
    log_warning "En tu primera visita a ${URL_BESZEL} deberás:"
    log_warning "  1. Crear una cuenta con email: ${ADMIN_EMAIL}"
    log_warning "  2. Usar tu contraseña admin"
fi

# ── Configurar nginx vhost ─────────────────────────────────
log_step "Configurando nginx para beszel.vpn.${DOMAIN}"

cat > "${NGINX_CONF_DIR}/beszel" << EOF
# VPSfacil-lite — Beszel Hub
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name beszel.vpn.${DOMAIN};

    include snippets/vpsfacil-ssl.conf;

    # Logs
    access_log /var/log/nginx/beszel-access.log;
    error_log  /var/log/nginx/beszel-error.log;

    location / {
        proxy_pass http://127.0.0.1:${PORT_BESZEL};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        # WebSocket support (necesario para Beszel)
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
    }
}
EOF

ln -sf "${NGINX_CONF_DIR}/beszel" "${NGINX_ENABLED_DIR}/beszel"
nginx -t && systemctl reload nginx
log_success "nginx configurado para Beszel ✓"

echo ""
log_success "Beszel Hub instalado en ${URL_BESZEL} ✓"
