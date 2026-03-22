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

# ── Mostrar clave privada SSH ──────────────────────────────
log_step "Tu clave privada SSH"

# Obtener IP Tailscale
TS_IP="${TAILSCALE_IP:-$(tailscale ip -4 2>/dev/null || echo '<IP_TAILSCALE>')}"

PRIVATE_KEY="${ADMIN_HOME}/.ssh/id_ed25519"

echo ""
echo -e "${COLOR_BOLD_RED}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}║          ⚠  COPIA ESTA CLAVE PRIVADA AHORA  ⚠               ║${COLOR_RESET}"
echo -e "${COLOR_BOLD_RED}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}Nota: la clave ed25519 es más corta que las claves RSA tradicionales,${COLOR_RESET}"
echo -e "${COLOR_YELLOW}pero es igual o más segura. Es el estándar moderno recomendado.${COLOR_RESET}"
echo ""
echo -e "${COLOR_BOLD_WHITE}── CLAVE PRIVADA (selecciona todo el bloque y cópialo) ──────────${COLOR_RESET}"
cat "${PRIVATE_KEY}"
echo -e "${COLOR_BOLD_WHITE}────────────────────────────────────────────────────────────────${COLOR_RESET}"
echo ""

echo -e "${COLOR_BOLD_WHITE}Cómo guardar y usar la clave en Windows 11 con Bitvise SSH:${COLOR_RESET}"
echo ""
echo -e "${COLOR_CYAN}  PASO A — Guardar el archivo${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}1. Copia todo el texto de arriba (desde -----BEGIN hasta -----END-----)${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}2. Abre el Bloc de notas en Windows${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}3. Pega el texto y guarda el archivo como: vpsfacil_key.pem${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}   (Asegúrate de que no tenga extensión .txt, solo .pem)${COLOR_RESET}"
echo ""
echo -e "${COLOR_CYAN}  PASO B — Importar en Bitvise SSH Client${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}1. Abre Bitvise SSH Client${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}2. En la pestaña 'Login', configura:${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}   · Host:              ${TS_IP}${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}   · Port:              22${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}   · Username:          ${ADMIN_USER}${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}   · Initial method:    publickey${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}3. Haz clic en 'Client key manager' (botón junto a 'Initial method')${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}4. Clic en 'Import' → selecciona el archivo vpsfacil_key.pem${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}5. Cierra el key manager${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}6. En 'Client key', selecciona la clave recién importada${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}7. Haz clic en 'Log in'${COLOR_RESET}"
echo ""
echo -e "${COLOR_CYAN}  PASO C — Conexión alternativa por terminal (PowerShell / WSL)${COLOR_RESET}"
echo -e "  ${COLOR_WHITE}  ssh -i C:\\ruta\\vpsfacil_key.pem ${ADMIN_USER}@${TS_IP}${COLOR_RESET}"
echo ""

wait_for_user "Presiona Enter cuando hayas copiado y guardado la clave privada..."

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
echo -e "${COLOR_BOLD_WHITE}Abre Bitvise (o una nueva terminal) y verifica que puedes conectarte${COLOR_RESET}"
echo -e "${COLOR_BOLD_WHITE}al servidor ANTES de responder 'sí' aquí.${COLOR_RESET}"
echo ""
echo -e "${COLOR_BOLD_RED}Si NO puedes conectarte, responde 'no' — NO pierdas el acceso.${COLOR_RESET}"
echo ""

if ! confirm "¿Pudiste conectarte al servidor con tu clave SSH?"; then
    echo ""
    log_error "Hardening SSH cancelado."
    log_info "Revisa la conexión usando los pasos de Bitvise descritos arriba."
    log_info "Cuando lo soluciones, ejecuta: bash /opt/vpsfacil-lite/scripts/09_finalize.sh"
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
