#!/bin/bash
# ============================================================
# lib/colors.sh — Colores ANSI y funciones de output
# VPSfacil-lite - Instalación Nativa sin Docker
# ============================================================

# --- Colores base ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD="\033[1m"

readonly COLOR_RED="\033[0;31m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_MAGENTA="\033[0;35m"
readonly COLOR_CYAN="\033[0;36m"
readonly COLOR_WHITE="\033[0;37m"

readonly COLOR_BOLD_RED="\033[1;31m"
readonly COLOR_BOLD_GREEN="\033[1;32m"
readonly COLOR_BOLD_YELLOW="\033[1;33m"
readonly COLOR_BOLD_BLUE="\033[1;34m"
readonly COLOR_BOLD_MAGENTA="\033[1;35m"
readonly COLOR_BOLD_CYAN="\033[1;36m"
readonly COLOR_BOLD_WHITE="\033[1;37m"

# --- Prefijos de mensajes ---
readonly PREFIX_INFO="${COLOR_BOLD_BLUE}[ℹ]${COLOR_RESET}"
readonly PREFIX_SUCCESS="${COLOR_BOLD_GREEN}[✓]${COLOR_RESET}"
readonly PREFIX_WARNING="${COLOR_BOLD_YELLOW}[⚠]${COLOR_RESET}"
readonly PREFIX_ERROR="${COLOR_BOLD_RED}[✗]${COLOR_RESET}"
readonly PREFIX_PROMPT="${COLOR_BOLD_CYAN}[?]${COLOR_RESET}"
readonly PREFIX_PROCESS="${COLOR_BOLD_MAGENTA}[⏳]${COLOR_RESET}"
readonly PREFIX_STEP="${COLOR_BOLD_WHITE}[→]${COLOR_RESET}"

# --- Función: Separador simple ---
print_separator() {
    echo -e "${COLOR_BLUE}────────────────────────────────────────────────────────────${COLOR_RESET}" >&2
}

# --- Función: Cabecera de sección ---
# Uso: print_header "Título de la sección"
print_header() {
    local title="$1"
    local width=60
    local title_len=${#title}
    local padding=$(( (width - title_len) / 2 ))
    local left_pad
    left_pad=$(printf '%*s' "$padding" '')
    local right_pad
    right_pad=$(printf '%*s' "$((width - title_len - padding))" '')

    echo "" >&2
    echo -e "${COLOR_BOLD_BLUE}╔$(printf '═%.0s' $(seq 1 $width))╗${COLOR_RESET}" >&2
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}${COLOR_BOLD_WHITE}${left_pad}${title}${right_pad}${COLOR_RESET}${COLOR_BOLD_BLUE}║${COLOR_RESET}" >&2
    echo -e "${COLOR_BOLD_BLUE}╚$(printf '═%.0s' $(seq 1 $width))╝${COLOR_RESET}" >&2
    echo "" >&2
}

# --- Función: Banner principal del proyecto ---
print_banner() {
    echo ""
    echo -e "${COLOR_BOLD_BLUE}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}                                                              ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN}██╗   ██╗██████╗ ███████╗███████╗ █████╗  ██████╗██╗██╗     ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN}██║   ██║██╔══██╗██╔════╝██╔════╝██╔══██╗██╔════╝██║██║     ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN}██║   ██║██████╔╝███████╗█████╗  ███████║██║     ██║██║     ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN}╚██╗ ██╔╝██╔═══╝ ╚════██║██╔══╝  ██╔══██║██║     ██║██║     ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN} ╚████╔╝ ██║     ███████║██║     ██║  ██║╚██████╗██║███████╗${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_GREEN}  ╚═══╝  ╚═╝     ╚══════╝╚═╝     ╚═╝  ╚═╝╚═════╝╚═╝╚══════╝${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}                                                              ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_BOLD_CYAN}        Instalación Automatizada de VPS v1.0            ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}  ${COLOR_WHITE}        Debian 12 · Docker · Tailscale VPN              ${COLOR_RESET}  ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}║${COLOR_RESET}                                                              ${COLOR_BOLD_BLUE}║${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}
