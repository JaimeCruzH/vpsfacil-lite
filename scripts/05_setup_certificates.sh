#!/bin/bash
# ============================================================
# Paso 6 de 9 — Certificados Let's Encrypt wildcard
# VPSfacil-lite - Instalación Nativa sin Docker
# Mismo proceso que VPSfacil: certificado manual via Cloudflare
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/colors.sh"
source "${SCRIPT_DIR}/../lib/config.sh"
source "${SCRIPT_DIR}/../lib/utils.sh"
source "${SCRIPT_DIR}/../lib/progress.sh"

source_config
print_header "Paso 6 de 9 — Certificados SSL"
show_progress 6 "Configurar certificados Let's Encrypt"
check_root

# TODO: Mismo proceso interactivo que VPSfacil
# TODO: Guiar al usuario en Cloudflare para generar el certificado wildcard
# TODO: Guardar en ${CERTS_DIR}/origin-cert.pem y origin-cert-key.pem
# TODO: chmod 600 ${CERT_KEY}
# TODO: Configurar nginx con el certificado wildcard para todos los subdominios

log_success "Certificados SSL configurados ✓"
