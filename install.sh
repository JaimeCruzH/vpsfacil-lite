#!/bin/bash
# ============================================================
# install.sh — Bootstrap de VPSfacil-lite
#
# Instala las dependencias mínimas (curl, git), clona el
# repositorio y lanza setup.sh de forma automática.
#
# Uso (un solo comando en el VPS):
#   bash <(curl -fsSL https://raw.githubusercontent.com/JaimeCruzH/vpsfacil-lite/main/install.sh)
# ============================================================

# Colores básicos (sin depender de lib/colors.sh aún)
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# ── Banner ──────────────────────────────────────────────────
clear
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BLUE}║${RESET}                                                              ${BLUE}║${RESET}"
echo -e "${BLUE}║${RESET}  ${GREEN}VPSfacil-lite${RESET} — Instalación Nativa sin Docker            ${BLUE}║${RESET}"
echo -e "${BLUE}║${RESET}  ${WHITE}Systemd · Nginx · Let's Encrypt · Tailscale VPN        ${RESET}  ${BLUE}║${RESET}"
echo -e "${BLUE}║${RESET}                                                              ${BLUE}║${RESET}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Verificar root ──────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[✗]${RESET} Este script debe ejecutarse como root."
    echo -e "${CYAN}[ℹ]${RESET} Intenta: sudo bash <(curl -fsSL https://raw.githubusercontent.com/JaimeCruzH/vpsfacil-lite/main/install.sh)"
    exit 1
fi

# ── Verificar que existe apt-get ────────────────────────────
if ! command -v apt-get &>/dev/null; then
    echo -e "${RED}[✗]${RESET} Este script requiere un sistema con apt (Debian, Ubuntu o compatible)."
    exit 1
fi

# ── Instalar dependencias mínimas ───────────────────────────
echo -e "${CYAN}[→]${RESET} Verificando herramientas necesarias..."
echo ""

DEPS_NEEDED=()
command -v curl &>/dev/null || DEPS_NEEDED+=("curl")
command -v git  &>/dev/null || DEPS_NEEDED+=("git")
command -v ca-certificates &>/dev/null 2>&1 || dpkg -l ca-certificates &>/dev/null || DEPS_NEEDED+=("ca-certificates")

if [[ ${#DEPS_NEEDED[@]} -gt 0 ]]; then
    echo -e "${CYAN}[→]${RESET} Instalando: ${DEPS_NEEDED[*]}"
    apt-get update -qq 2>/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${DEPS_NEEDED[@]}" 2>/dev/null
    echo -e "${GREEN}[✓]${RESET} Dependencias instaladas"
else
    echo -e "${GREEN}[✓]${RESET} curl y git ya disponibles"
fi

echo ""

# ── Clonar o actualizar repositorio ─────────────────────────
INSTALL_DIR="/opt/vpsfacil-lite"
REPO_URL="https://github.com/JaimeCruzH/vpsfacil-lite"

if [[ -d "${INSTALL_DIR}/.git" ]]; then
    echo -e "${CYAN}[→]${RESET} Actualizando repositorio en ${INSTALL_DIR}..."
    # Forzar actualización: fetch + reset al estado exacto del repo remoto
    git -C "${INSTALL_DIR}" fetch origin main 2>&1
    git -C "${INSTALL_DIR}" reset --hard origin/main 2>&1
    echo -e "${GREEN}[✓]${RESET} Repositorio actualizado al último commit"
else
    echo -e "${CYAN}[→]${RESET} Clonando repositorio en ${INSTALL_DIR}..."
    rm -rf "${INSTALL_DIR}"
    git clone "${REPO_URL}" "${INSTALL_DIR}"
    echo -e "${GREEN}[✓]${RESET} Repositorio clonado"
fi

# Dar permisos de ejecución a los scripts
chmod +x "${INSTALL_DIR}/setup.sh"
chmod +x "${INSTALL_DIR}/scripts/"*.sh

echo ""
echo -e "${GREEN}[✓]${RESET} Listo. Iniciando instalación..."
echo ""
sleep 1

# ── Lanzar setup.sh (reemplaza este proceso) ─────────────────
exec bash "${INSTALL_DIR}/setup.sh"
