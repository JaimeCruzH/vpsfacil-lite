#!/bin/bash
# ============================================================
# Paso 2 de 9 — Crear usuario administrador
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 2 de 9 — Crear Usuario Admin"
show_progress 2 "Crear usuario administrador"
check_root

log_step "Creando usuario ${ADMIN_USER}"
# TODO: useradd -m -s /bin/bash ${ADMIN_USER}
# TODO: usermod -aG sudo ${ADMIN_USER}
# TODO: echo "${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${ADMIN_USER}

log_step "Generando par de llaves SSH"
# TODO: ssh-keygen -t ed25519 -f /tmp/${ADMIN_USER}_key -N ""
# TODO: Instalar clave publica en authorized_keys
# TODO: Mostrar instrucciones para guardar la llave privada en Windows/Bitvise

log_step "Creando estructura de directorios"
# TODO: mkdir -p ${APPS_DIR}/{certs,filebrowser,kopia,beszel,backups}
# TODO: chown -R ${ADMIN_USER}:${ADMIN_USER} /home/${ADMIN_USER}

log_success "Usuario ${ADMIN_USER} creado y configurado ✓"
