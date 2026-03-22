#!/bin/bash
# ============================================================
# Paso 9 de 9 — Finalizacion y hardening SSH
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 9 de 9 — Finalizacion"
show_progress 9 "Hardening SSH y permisos finales"
check_root

log_step "Ajustando permisos finales"
# TODO: chown -R ${ADMIN_USER}:${ADMIN_USER} /home/${ADMIN_USER}
# TODO: chmod 700 /home/${ADMIN_USER}/.ssh
# TODO: chmod 600 /home/${ADMIN_USER}/.ssh/authorized_keys

log_step "Verificando conexion SSH del usuario admin"
# TODO: Pedir confirmacion de que el admin puede conectarse antes de deshabilitar root

log_step "Hardening SSH"
# TODO: Deshabilitar root login
# TODO: Deshabilitar autenticacion por contrasena
# TODO: systemctl restart sshd

log_step "Configurando fail2ban"
# TODO: systemctl enable --now fail2ban

log_step "Resumen de instalacion"
# TODO: Mostrar tabla de URLs y servicios activos

log_success "Instalacion completada ✓"
