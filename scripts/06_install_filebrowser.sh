#!/bin/bash
# ============================================================
# Paso 7 de 9 — Instalar File Browser (binario nativo)
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 7 de 9 — File Browser"
show_progress 7 "Instalar File Browser"
check_root

APP_DIR="${APPS_DIR}/filebrowser"

log_step "Descargando binario de File Browser"
# TODO: Descargar release mas reciente desde GitHub
# TODO: Instalar en /usr/local/bin/filebrowser

log_step "Inicializando base de datos"
# TODO: mkdir -p ${APP_DIR}
# TODO: filebrowser config init --database ${APP_DIR}/filebrowser.db
# TODO: filebrowser config set --address 127.0.0.1 --port ${PORT_FILEBROWSER} --root /home/${ADMIN_USER}

log_step "Creando servicio systemd"
# TODO: Escribir /etc/systemd/system/filebrowser.service
# TODO: systemctl daemon-reload && systemctl enable --now filebrowser

log_step "Configurando nginx"
# TODO: Virtual host: files.vpn.${DOMAIN} -> 127.0.0.1:${PORT_FILEBROWSER}
# TODO: Con certificado wildcard Let's Encrypt

log_success "File Browser instalado en https://files.vpn.${DOMAIN} ✓"
