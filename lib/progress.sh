#!/bin/bash
# ============================================================
# lib/progress.sh — Tracking de progreso visual
# VPSfacil-lite - Instalación Nativa sin Docker
# 10 pasos de instalación core
# ============================================================

readonly TOTAL_STEPS=10

CURRENT_STEP=0

show_progress() {
    local step="$1"
    local description="$2"
    CURRENT_STEP=$step

    echo ""
    echo -e "${COLOR_BOLD_BLUE}┌─ Progreso ─────────────────────────────────────────────────┐${COLOR_RESET}"
    echo -e "${COLOR_BOLD_BLUE}│${COLOR_RESET}  Paso ${COLOR_BOLD_WHITE}${step}${COLOR_RESET} de ${COLOR_BOLD_WHITE}${TOTAL_STEPS}${COLOR_RESET}: ${COLOR_CYAN}${description}${COLOR_RESET}"

    # Barra de progreso
    local filled=$(( (step * 50) / TOTAL_STEPS ))
    local empty=$(( 50 - filled ))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++));  do bar+="░"; done
    local pct=$(( (step * 100) / TOTAL_STEPS ))

    echo -e "${COLOR_BOLD_BLUE}│${COLOR_RESET}  ${COLOR_BOLD_GREEN}${bar}${COLOR_RESET} ${pct}%"
    echo -e "${COLOR_BOLD_BLUE}└────────────────────────────────────────────────────────────┘${COLOR_RESET}"
    echo ""
}
