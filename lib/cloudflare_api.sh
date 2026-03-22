#!/bin/bash
# ============================================================
# lib/cloudflare_api.sh — Wrapper para Cloudflare API v4
# VPSfacil-lite - Instalación Nativa sin Docker
#
# Requiere:
#   - $CF_API_TOKEN exportado (cargado desde setup.conf)
#   - curl y jq instalados
# ============================================================

readonly CF_API_BASE="https://api.cloudflare.com/client/v4"

# ============================================================
# cf_api_call — Llamada genérica a la API de Cloudflare
# Uso: cf_api_call METHOD /endpoint [json_body]
# Retorna: respuesta JSON completa
# ============================================================
cf_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    if [[ -z "${CF_API_TOKEN:-}" ]]; then
        log_error "CF_API_TOKEN no está definido. Ejecuta setup.sh primero."
        return 1
    fi

    local curl_args=(
        -sf
        -X "$method"
        -H "Authorization: Bearer ${CF_API_TOKEN}"
        -H "Content-Type: application/json"
    )

    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi

    local response
    response=$(curl "${curl_args[@]}" "${CF_API_BASE}${endpoint}" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        log_error "Error de red al contactar Cloudflare API."
        return 1
    fi

    echo "$response"
}

# ============================================================
# cf_get_zone_id — Obtener el Zone ID de un dominio
# Uso: cf_get_zone_id "midominio.com"
# Retorna: zone_id (string) o error
# ============================================================
cf_get_zone_id() {
    local domain="$1"

    log_process "Obteniendo Zone ID para ${domain}..."

    local response
    response=$(cf_api_call GET "/zones?name=${domain}&status=active")

    local success
    success=$(echo "$response" | jq -r '.success' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.errors[0].message // "Error desconocido"' 2>/dev/null)
        log_error "Cloudflare API error: ${error_msg}"
        log_error "Verifica que el dominio '${domain}' esté en tu cuenta de Cloudflare."
        return 1
    fi

    local zone_id
    zone_id=$(echo "$response" | jq -r '.result[0].id // empty' 2>/dev/null)

    if [[ -z "$zone_id" ]]; then
        log_error "No se encontró la zona para el dominio '${domain}'."
        log_error "Asegúrate de que el dominio esté agregado a tu cuenta Cloudflare."
        return 1
    fi

    log_success "Zone ID: ${zone_id}"
    echo "$zone_id"
}

# ============================================================
# cf_list_dns_records — Listar registros DNS por nombre
# Uso: cf_list_dns_records "zone_id" "nombre.dominio.com"
# Retorna: JSON con array .result de registros encontrados
# ============================================================
cf_list_dns_records() {
    local zone_id="$1"
    local name="$2"

    local response
    response=$(cf_api_call GET "/zones/${zone_id}/dns_records?type=A&name=${name}")

    local success
    success=$(echo "$response" | jq -r '.success' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.errors[0].message // "Error desconocido"' 2>/dev/null)
        log_error "Error al listar registros DNS: ${error_msg}"
        return 1
    fi

    echo "$response"
}

# ============================================================
# cf_create_dns_record — Crear un registro DNS tipo A
# Uso: cf_create_dns_record "zone_id" "nombre.dominio.com" "1.2.3.4" "false"
# ============================================================
cf_create_dns_record() {
    local zone_id="$1"
    local name="$2"
    local content="$3"
    local proxied="${4:-false}"

    local payload
    payload=$(printf '{"type":"A","name":"%s","content":"%s","proxied":%s,"ttl":1}' \
        "$name" "$content" "$proxied")

    local response
    response=$(cf_api_call POST "/zones/${zone_id}/dns_records" "$payload")

    local success
    success=$(echo "$response" | jq -r '.success' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.errors[0].message // "Error desconocido"' 2>/dev/null)
        log_error "Error al crear registro DNS '${name}': ${error_msg}"
        return 1
    fi

    log_success "Creado: ${name} → ${content}"
}

# ============================================================
# cf_update_dns_record — Actualizar un registro DNS existente
# Uso: cf_update_dns_record "zone_id" "record_id" "nombre.dominio.com" "1.2.3.4" "false"
# ============================================================
cf_update_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    local name="$3"
    local content="$4"
    local proxied="${5:-false}"

    local payload
    payload=$(printf '{"type":"A","name":"%s","content":"%s","proxied":%s,"ttl":1}' \
        "$name" "$content" "$proxied")

    local response
    response=$(cf_api_call PUT "/zones/${zone_id}/dns_records/${record_id}" "$payload")

    local success
    success=$(echo "$response" | jq -r '.success' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.errors[0].message // "Error desconocido"' 2>/dev/null)
        log_error "Error al actualizar registro DNS '${name}': ${error_msg}"
        return 1
    fi

    log_success "Actualizado: ${name} → ${content}"
}

# ============================================================
# cf_upsert_dns_record — Crear o actualizar un registro DNS A
# (idempotente: si ya existe lo actualiza, si no lo crea)
# Uso: cf_upsert_dns_record "zone_id" "nombre.dominio.com" "1.2.3.4"
# ============================================================
cf_upsert_dns_record() {
    local zone_id="$1"
    local name="$2"
    local content="$3"
    local proxied="${4:-false}"

    local records_response
    records_response=$(cf_list_dns_records "$zone_id" "$name") || return 1

    local record_count
    record_count=$(echo "$records_response" | jq -r '.result | length' 2>/dev/null)

    if [[ "$record_count" -gt 0 ]]; then
        local record_id
        record_id=$(echo "$records_response" | jq -r '.result[0].id' 2>/dev/null)
        cf_update_dns_record "$zone_id" "$record_id" "$name" "$content" "$proxied"
    else
        cf_create_dns_record "$zone_id" "$name" "$content" "$proxied"
    fi
}
