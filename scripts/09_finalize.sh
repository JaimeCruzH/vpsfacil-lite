#!/bin/bash
# ============================================================
# Paso 10 de 10 — Finalización: hardening SSH y resumen
# VPSfacil-lite - Instalación Nativa sin Docker
#
# IMPORTANTE: Este paso deshabilitará el login SSH por
# contraseña. Asegúrate de tener tu clave privada guardada
# antes de continuar.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 10 de 10 — Finalización"
show_progress 10 "Hardening SSH, fail2ban y resumen final"
check_root

# ── Permisos finales ───────────────────────────────────────
log_step "Ajustando permisos finales"

chmod 750 "${ADMIN_HOME}"
chmod 700 "${ADMIN_HOME}/.ssh"
chmod 600 "${ADMIN_HOME}/.ssh/authorized_keys"
chmod 600 "${ADMIN_HOME}/.ssh/id_ed25519"
chmod 644 "${ADMIN_HOME}/.ssh/id_ed25519.pub"
chown -R "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_HOME}"
mkdir -p "${LOG_DIR}"
log_success "Permisos configurados ✓"

# ── Habilitar fail2ban ─────────────────────────────────────
log_step "Configurando fail2ban"

systemctl enable fail2ban
systemctl start fail2ban
log_success "fail2ban activo ✓"

# ── Verificar todos los servicios ─────────────────────────
log_step "Verificando servicios instalados"
echo ""

ALL_OK=true
for svc in nginx tailscaled filebrowser kopia beszel; do
    if systemctl is-active --quiet "${svc}"; then
        echo -e "  ${COLOR_BOLD_GREEN}✓${COLOR_RESET}  ${svc}"
    else
        echo -e "  ${COLOR_BOLD_RED}✗${COLOR_RESET}  ${svc} ${COLOR_YELLOW}(no está activo)${COLOR_RESET}"
        ALL_OK=false
    fi
done
echo ""

if [[ "$ALL_OK" == "false" ]]; then
    log_warning "Algunos servicios no están activos. Revisa con: systemctl status <servicio>"
fi

# ── PAUSA CRÍTICA: verificar SSH antes de hardening ───────
echo ""
echo -e "${COLOR_BOLD_RED}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}║      ⚠  ACCIÓN REQUERIDA ANTES DE CONTINUAR  ⚠              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}╠══════════════════════════════════════════════════════════════╣${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}║  El siguiente paso deshabilitará el acceso SSH por           ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}║  contraseña. Solo podrás conectarte con tu clave SSH.        ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""

# Obtener IP Tailscale para mostrar el comando de conexión
TS_IP="${TAILSCALE_IP:-$(tailscale ip -4 2>/dev/null || echo '<IP_TAILSCALE>')}"

echo -e "${COLOR_BOLD_WHITE}Abre una NUEVA terminal y verifica que puedes conectarte:${COLOR_RESET}"
echo ""
echo -e "  ${COLOR_CYAN}ssh -i /ruta/a/vpsfacil_key.pem ${ADMIN_USER}@${TS_IP}${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}Tu clave privada SSH se guardó en: ${ADMIN_HOME}/.ssh/id_ed25519${COLOR_RESET}"
echo -e "${COLOR_YELLOW}Debes haberla copiado en el Paso 2 de la instalación.${COLOR_RESET}"
echo ""
echo -e "${COLOR_BOLD_RED}Si NO puedes conectarte, escribe 'no' y NO continúes.${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}De lo contrario perderás el acceso al servidor.${COLOR_RESET}"
echo ""

if ! confirm "¿Pudiste conectarte al servidor con tu clave SSH?"; then
    echo ""
    log_error "Hardening SSH cancelado por el usuario."
    log_info "Para depurar la conexión SSH, ejecuta en tu computadora:"
    log_info "  ssh -v -i /ruta/a/tu_clave.pem ${ADMIN_USER}@${TS_IP}"
    log_info ""
    log_info "Cuando soluciones el problema, ejecuta manualmente:"
    log_info "  bash ${SCRIPT_DIR}/09_finalize.sh"
    exit 0
fi

# ── Hardening SSH ──────────────────────────────────────────
log_step "Aplicando hardening SSH"

SSHD_CONFIG="/etc/ssh/sshd_config"

# Hacer backup del config original
cp "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%Y%m%d%H%M%S)"

# Deshabilitar login como root
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CONFIG}"
grep -q "^PermitRootLogin" "${SSHD_CONFIG}" || echo "PermitRootLogin no" >> "${SSHD_CONFIG}"

# Deshabilitar autenticación por contraseña
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
grep -q "^PasswordAuthentication" "${SSHD_CONFIG}" || echo "PasswordAuthentication no" >> "${SSHD_CONFIG}"

# Habilitar autenticación por clave pública
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "${SSHD_CONFIG}"
grep -q "^PubkeyAuthentication" "${SSHD_CONFIG}" || echo "PubkeyAuthentication yes" >> "${SSHD_CONFIG}"

# Verificar configuración antes de reiniciar
if sshd -t 2>/dev/null; then
    systemctl restart sshd
    log_success "SSH hardening aplicado ✓"
    log_success "  - Login root: DESHABILITADO"
    log_success "  - Autenticación por contraseña: DESHABILITADA"
    log_success "  - Autenticación por clave SSH: HABILITADA"
else
    log_error "Error en la configuración SSH. Restaurando backup..."
    cp "${SSHD_CONFIG}.bak."* "${SSHD_CONFIG}" 2>/dev/null || true
    log_info "Configuración SSH restaurada. Revisa manualmente ${SSHD_CONFIG}."
    exit 1
fi

# ── Resumen final ──────────────────────────────────────────
echo ""
echo -e "${COLOR_BOLD_GREEN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║          ✓  VPSfacil-lite — Instalación Completa  ✓         ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}╠══════════════════════════════════════════════════════════════╣${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_BOLD_WHITE}APLICACIONES (activa Tailscale para acceder)${COLOR_RESET}              ${COLOR_BOLD_GREEN}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}File Browser:${COLOR_RESET}  ${COLOR_CYAN}${URL_FILEBROWSER}${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}Kopia Backup:${COLOR_RESET}  ${COLOR_CYAN}${URL_KOPIA}${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}Beszel Hub:${COLOR_RESET}    ${COLOR_CYAN}${URL_BESZEL}${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}╠══════════════════════════════════════════════════════════════╣${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_BOLD_WHITE}ACCESO SSH${COLOR_RESET}                                                ${COLOR_BOLD_GREEN}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}ssh -i vpsfacil_key.pem ${ADMIN_USER}@${TS_IP}${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}╠══════════════════════════════════════════════════════════════╣${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_BOLD_WHITE}CREDENCIALES${COLOR_RESET}                                              ${COLOR_BOLD_GREEN}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}Usuario:${COLOR_RESET}     ${COLOR_CYAN}${ADMIN_USER}${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}Contraseña:${COLOR_RESET}  ${COLOR_CYAN}(la que configuraste al inicio)${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_WHITE}Email Beszel:${COLOR_RESET} ${COLOR_CYAN}${ADMIN_USER}@${DOMAIN}${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}╠══════════════════════════════════════════════════════════════╣${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_YELLOW}⚠  Tu clave SSH privada está en:${COLOR_RESET}                           ${COLOR_BOLD_GREEN}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_CYAN}   ${ADMIN_HOME}/.ssh/id_ed25519${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║  ${COLOR_YELLOW}   Asegúrate de tenerla guardada en tu PC.${COLOR_RESET}                 ${COLOR_BOLD_GREEN}║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}║                                                              ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_GREEN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""

log_success "¡VPSfacil-lite instalado y configurado correctamente!"
