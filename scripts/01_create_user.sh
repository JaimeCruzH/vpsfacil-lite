#!/bin/bash
# ============================================================
# Paso 2 de 10 — Crear usuario administrador
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 2 de 10 — Crear Usuario Administrador"
show_progress 2 "Crear usuario administrador"
check_root

# ── Crear usuario ──────────────────────────────────────────
log_step "Creando usuario '${ADMIN_USER}'"

if id -u "${ADMIN_USER}" &>/dev/null; then
    log_info "El usuario '${ADMIN_USER}' ya existe. Actualizando configuración..."
else
    useradd -m -s /bin/bash "${ADMIN_USER}"
    log_success "Usuario '${ADMIN_USER}' creado ✓"
fi

# Establecer contraseña
echo "${ADMIN_USER}:${ADMIN_PASSWORD}" | chpasswd
log_success "Contraseña configurada ✓"

# ── Configurar sudoers ─────────────────────────────────────
log_step "Configurando permisos sudo sin contraseña"
echo "${ADMIN_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/${ADMIN_USER}"
chmod 440 "/etc/sudoers.d/${ADMIN_USER}"
log_success "Sudoers configurado ✓"

# ── Crear estructura de directorios ───────────────────────
log_step "Creando estructura de directorios"
mkdir -p "${APPS_DIR}/filebrowser"
mkdir -p "${APPS_DIR}/kopia"
mkdir -p "${APPS_DIR}/beszel"
mkdir -p "${APPS_DIR}/backups"
mkdir -p "${APPS_DIR}/certs"
mkdir -p "${LOG_DIR}"
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_HOME}"
log_success "Directorios creados en ${APPS_DIR} ✓"

# ── Generar clave SSH ed25519 ──────────────────────────────
log_step "Generando clave SSH ed25519"

SSH_DIR="${ADMIN_HOME}/.ssh"
PRIVATE_KEY="${SSH_DIR}/id_ed25519"
PUBLIC_KEY="${SSH_DIR}/id_ed25519.pub"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

if [[ -f "$PRIVATE_KEY" ]]; then
    log_info "Ya existe una clave SSH. Omitiendo generación."
else
    mkdir -p "$SSH_DIR"
    ssh-keygen -q -t ed25519 -f "$PRIVATE_KEY" -N "" -C "vpsfacil-admin@${DOMAIN}"
    log_success "Par de claves SSH generado ✓"
fi

# Agregar clave pública a authorized_keys (idempotente)
if ! grep -qF "$(cat "${PUBLIC_KEY}")" "${AUTHORIZED_KEYS}" 2>/dev/null; then
    cat "${PUBLIC_KEY}" >> "${AUTHORIZED_KEYS}"
fi

# Establecer permisos correctos
chmod 700 "$SSH_DIR"
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"
chmod 600 "$AUTHORIZED_KEYS"
chown -R "${ADMIN_USER}:${ADMIN_USER}" "$SSH_DIR"

log_success "Clave SSH configurada en authorized_keys ✓"
log_info "La clave privada se mostrará al final de la instalación (paso 10)."
log_info "La clave está guardada en: ${PRIVATE_KEY}"

log_success "Usuario '${ADMIN_USER}' creado y configurado ✓"
