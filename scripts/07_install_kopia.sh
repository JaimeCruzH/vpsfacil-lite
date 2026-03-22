#!/bin/bash
# ============================================================
# Paso 8 de 10 — Instalar Kopia Backup Server
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 8 de 10 — Kopia Backup"
show_progress 8 "Instalar Kopia Backup Server"
check_root

APP_DIR="${APPS_DIR}/kopia"

# ── Instalar Kopia via repositorio oficial ─────────────────
log_step "Configurando repositorio APT de Kopia"

KOPIA_KEYRING="/usr/share/keyrings/kopia-keyring.gpg"

if [[ ! -f "${KOPIA_KEYRING}" ]]; then
    curl -sf https://kopia.io/signing-key \
        | gpg --dearmor -o "${KOPIA_KEYRING}"
    log_success "Clave GPG de Kopia agregada ✓"
fi

# Detectar distribución y codename
DISTRO_CODENAME=$(lsb_release -cs 2>/dev/null || echo "bookworm")

cat > /etc/apt/sources.list.d/kopia.list << EOF
deb [signed-by=${KOPIA_KEYRING}] https://packages.kopia.io/apt/ stable main
EOF

log_step "Instalando Kopia"
wait_for_dpkg
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq kopia
log_success "Kopia instalado ✓"
kopia --version

# ── Crear directorio de trabajo ────────────────────────────
log_step "Configurando directorios de Kopia"

mkdir -p "${APP_DIR}"
mkdir -p "${APPS_DIR}/backups"
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APP_DIR}"
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${APPS_DIR}/backups"

# ── Crear servicio systemd ─────────────────────────────────
log_step "Creando servicio systemd para Kopia Server"

cat > "${SYSTEMD_DIR}/kopia.service" << EOF
[Unit]
Description=Kopia Backup Server
After=network.target

[Service]
User=${ADMIN_USER}
Group=${ADMIN_USER}
WorkingDirectory=${APP_DIR}
Environment=HOME=${ADMIN_HOME}
Environment=KOPIA_PASSWORD=${ADMIN_PASSWORD}
ExecStart=/usr/bin/kopia server start \\
    --address=127.0.0.1:${PORT_KOPIA} \\
    --server-username=${ADMIN_USER} \\
    --server-password=${ADMIN_PASSWORD} \\
    --server-tls-generate-cert=false \\
    --no-grpc
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kopia
systemctl restart kopia

sleep 2
if ! systemctl is-active --quiet kopia; then
    log_error "El servicio kopia no pudo iniciarse."
    log_info "Revisa los logs con: journalctl -u kopia -n 30"
    exit 1
fi
log_success "Servicio kopia activado ✓"

# Esperar a que el servicio esté listo
wait_for_port "127.0.0.1" "${PORT_KOPIA}" "${TIMEOUT_SERVICE_START}"

# ── Configurar nginx vhost ─────────────────────────────────
log_step "Configurando nginx para kopia.vpn.${DOMAIN}"

cat > "${NGINX_CONF_DIR}/kopia" << EOF
# VPSfacil-lite — Kopia Backup Server
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name kopia.vpn.${DOMAIN};

    include snippets/vpsfacil-ssl.conf;

    # Logs
    access_log /var/log/nginx/kopia-access.log;
    error_log  /var/log/nginx/kopia-error.log;

    # Tamaño máximo para uploads de backup
    client_max_body_size 0;

    location / {
        proxy_pass http://127.0.0.1:${PORT_KOPIA};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
EOF

ln -sf "${NGINX_CONF_DIR}/kopia" "${NGINX_ENABLED_DIR}/kopia"
nginx -t && systemctl reload nginx
log_success "nginx configurado para Kopia ✓"

echo ""
log_success "Kopia Backup instalado en ${URL_KOPIA} ✓"
log_info "  Usuario: ${ADMIN_USER}"
log_info "  Contraseña: (la que configuraste al inicio)"
log_info ""
log_info "  Nota: En la primera visita deberás conectar un repositorio de backup."
log_info "  Puedes usar el directorio local: ${APPS_DIR}/backups"
