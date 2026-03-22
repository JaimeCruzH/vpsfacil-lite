#!/bin/bash
# ============================================================
# Paso 7 de 10 — Instalar File Browser (binario nativo)
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 7 de 10 — File Browser"
show_progress 7 "Instalar File Browser"
check_root

APP_DIR="${APPS_DIR}/filebrowser"
DB_FILE="${APP_DIR}/filebrowser.db"

# ── Descargar e instalar binario ───────────────────────────
log_step "Descargando File Browser desde GitHub"

# Detectar arquitectura
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
    amd64|x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    armv7l|armhf) ARCH="armv7" ;;
    *)
        log_error "Arquitectura no soportada: ${ARCH}"
        exit 1
        ;;
esac

log_process "Obteniendo URL del release más reciente (arch: ${ARCH})..."
RELEASE_URL=$(curl -sf "https://api.github.com/repos/filebrowser/filebrowser/releases/latest" \
    | jq -r --arg arch "linux-${ARCH}" \
        '.assets[] | select((.name | contains($arch)) and (.name | endswith(".tar.gz"))) | .browser_download_url' \
    | head -1)

if [[ -z "$RELEASE_URL" ]]; then
    log_error "No se encontró el binario de File Browser para ${ARCH}."
    log_info "Verifica en: https://github.com/filebrowser/filebrowser/releases"
    exit 1
fi

log_process "Descargando: ${RELEASE_URL}"
TMPDIR_FB=$(mktemp -d)
curl -fsSL "${RELEASE_URL}" -o "${TMPDIR_FB}/filebrowser.tar.gz"
tar -xzf "${TMPDIR_FB}/filebrowser.tar.gz" -C "${TMPDIR_FB}"
install -m 755 "${TMPDIR_FB}/filebrowser" "${BIN_DIR}/filebrowser"
rm -rf "${TMPDIR_FB}"

log_success "File Browser instalado en ${BIN_DIR}/filebrowser ✓"
filebrowser version 2>/dev/null || true

# ── Inicializar base de datos ──────────────────────────────
log_step "Inicializando base de datos de File Browser"

mkdir -p "${APP_DIR}"
chown "${ADMIN_USER}:${ADMIN_USER}" "${APP_DIR}"

if [[ -f "${DB_FILE}" ]]; then
    log_info "Base de datos existente detectada. Omitiendo inicialización y creación de usuario."
else
    filebrowser config init --database "${DB_FILE}"
    filebrowser config set \
        --database "${DB_FILE}" \
        --address 127.0.0.1 \
        --port "${PORT_FILEBROWSER}" \
        --root "${ADMIN_HOME}"
    log_success "Base de datos inicializada ✓"

    filebrowser users add "${ADMIN_USER}" "${ADMIN_PASSWORD}" \
        --perm.admin \
        --database "${DB_FILE}"
    log_success "Usuario '${ADMIN_USER}' creado en File Browser ✓"
fi

chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_DIR}"

# ── Crear servicio systemd ─────────────────────────────────
log_step "Creando servicio systemd para File Browser"

cat > "${SYSTEMD_DIR}/filebrowser.service" << EOF
[Unit]
Description=File Browser - Explorador de archivos web
After=network.target

[Service]
User=${ADMIN_USER}
Group=${ADMIN_USER}
ExecStart=${BIN_DIR}/filebrowser --database ${DB_FILE}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable filebrowser
systemctl restart filebrowser

# Verificar que el servicio arrancó correctamente
sleep 2
if ! systemctl is-active --quiet filebrowser; then
    log_error "El servicio filebrowser no pudo iniciarse."
    log_info "Revisa los logs con: journalctl -u filebrowser -n 30"
    exit 1
fi
log_success "Servicio filebrowser activado ✓"

# Esperar a que el servicio esté listo
wait_for_port "127.0.0.1" "${PORT_FILEBROWSER}" "${TIMEOUT_SERVICE_START}"

# ── Configurar nginx vhost ─────────────────────────────────
log_step "Configurando nginx para files.vpn.${DOMAIN}"

cat > "${NGINX_CONF_DIR}/filebrowser" << EOF
# VPSfacil-lite — File Browser
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name files.vpn.${DOMAIN};

    include snippets/vpsfacil-ssl.conf;

    # Logs
    access_log /var/log/nginx/filebrowser-access.log;
    error_log  /var/log/nginx/filebrowser-error.log;

    location / {
        proxy_pass http://127.0.0.1:${PORT_FILEBROWSER};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 120s;
    }
}
EOF

ln -sf "${NGINX_CONF_DIR}/filebrowser" "${NGINX_ENABLED_DIR}/filebrowser"
nginx -t && systemctl reload nginx
log_success "nginx configurado para File Browser ✓"

echo ""
log_success "File Browser instalado en ${URL_FILEBROWSER} ✓"
log_info "  Usuario: ${ADMIN_USER}"
log_info "  Contraseña: (la que configuraste al inicio)"
