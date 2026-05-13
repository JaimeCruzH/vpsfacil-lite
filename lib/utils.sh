#!/bin/bash
# ============================================================
# lib/utils.sh — Funciones de utilidad comunes
# VPSfacil-lite - Instalación Nativa sin Docker
#
# IMPORTANTE: Este archivo depende de lib/config.sh y
# lib/colors.sh. Siempre se cargan juntos desde setup.sh
# ============================================================

# ============================================================
# FUNCIONES DE LOGGING
# ============================================================

log_info() {
    echo -e "${PREFIX_INFO} $1" >&2
}

log_success() {
    echo -e "${PREFIX_SUCCESS} $1" >&2
}

log_warning() {
    echo -e "${PREFIX_WARNING} $1" >&2
}

log_error() {
    echo -e "${PREFIX_ERROR} $1" >&2
}

log_prompt() {
    echo -e "${PREFIX_PROMPT} $1" >&2
}

log_process() {
    echo -e "${PREFIX_PROCESS} $1" >&2
}

log_step() {
    echo "" >&2
    echo -e "${PREFIX_STEP} ${COLOR_BOLD_WHITE}$1${COLOR_RESET}" >&2
    echo -e "${COLOR_BLUE}$(printf '─%.0s' $(seq 1 55))${COLOR_RESET}" >&2
}

# ============================================================
# VERIFICACIONES DE USUARIO Y SISTEMA
# ============================================================

# Verificar que se ejecuta como root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
        log_info  "Usa: sudo bash $0"
        exit 1
    fi
}

# Verificar conectividad a internet
check_internet() {
    log_process "Verificando conectividad a internet..."
    if curl -s --max-time 10 https://www.google.com > /dev/null 2>&1; then
        log_success "Conectividad a internet confirmada"
        return 0
    else
        log_error "Sin conectividad a internet"
        log_info  "Verifica la configuración de red del VPS antes de continuar"
        return 1
    fi
}

# Verificar que un comando existe en el sistema
command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================================
# CONFIRMACIONES Y INPUT DEL USUARIO
# ============================================================

# Confirmación S/N
# Uso: confirm "¿Deseas continuar?" && echo "Sí" || echo "No"
confirm() {
    local prompt="$1"
    local respuesta

    while true; do
        echo -ne "${PREFIX_PROMPT} ${prompt} ${COLOR_BOLD_WHITE}(sí/no)${COLOR_RESET}: " >&2
        read -r respuesta < /dev/tty
        # Limpiar espacios en blanco al inicio y final
        respuesta="$(echo "$respuesta" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        case "${respuesta,,}" in
            si|sí|s|yes|y) return 0 ;;
            no|n)           return 1 ;;
            "") ;; # Input vacío - mostrar advertencia
            *) log_warning "Por favor responde 'sí' o 'no'" ;;
        esac
    done
}

# Pedir dato al usuario con valor por defecto opcional
# Uso: valor=$(prompt_input "¿Cuál es tu dominio?" "example.com")
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local respuesta

    # >&2 para que el prompt se muestre en pantalla aunque la función
    # se llame dentro de $(...) donde stdout está capturado
    if [[ -n "$default" ]]; then
        echo -ne "${PREFIX_PROMPT} ${prompt} ${COLOR_CYAN}[${default}]${COLOR_RESET}: " >&2
    else
        echo -ne "${PREFIX_PROMPT} ${prompt}: " >&2
    fi

    read -r respuesta < /dev/tty
    # Limpiar espacios en blanco al inicio y final
    respuesta="$(echo "$respuesta" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

    if [[ -z "$respuesta" && -n "$default" ]]; then
        echo "$default"
    else
        echo "$respuesta"
    fi
}

# Pedir contraseña sin mostrarla en pantalla
# Uso: pass=$(prompt_password "Ingresa la contraseña")
prompt_password() {
    local prompt="$1"
    local pass

    # >&2 para que el prompt sea visible aunque se llame dentro de $(...)
    echo -ne "${PREFIX_PROMPT} ${prompt}: " >&2
    read -rs pass < /dev/tty
    # Limpiar espacios en blanco al inicio y final
    pass="$(echo "$pass" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    echo "" >&2
    echo "$pass"
}

# Pausar y esperar que el usuario presione Enter
wait_for_user() {
    local mensaje="${1:-Presiona Enter para continuar...}"
    echo ""
    echo -e "${PREFIX_PROMPT} ${mensaje}"
    # Leer entrada del usuario - intenta desde /dev/tty, fallback a stdin
    read -r < /dev/tty 2>/dev/null || read -r 2>/dev/null || true
    echo ""
}

# ============================================================
# HEALTH CHECKS
# ============================================================

# Esperar que un puerto esté disponible
# Uso: wait_for_port "localhost" 9000 60
wait_for_port() {
    local host="$1"
    local port="$2"
    local timeout="${3:-60}"
    local elapsed=0

    log_process "Esperando que el puerto ${port} esté disponible (máx. ${timeout}s)..."

    while ! timeout 1 bash -c "echo > /dev/tcp/${host}/${port}" 2>/dev/null; do
        elapsed=$((elapsed + 2))
        if [[ $elapsed -ge $timeout ]]; then
            log_error "El puerto ${port} no respondió en ${timeout} segundos"
            return 1
        fi
        printf "." >&2
        sleep 2
    done

    echo "" >&2
    log_success "Puerto ${port} disponible"
    return 0
}

# ============================================================
# ESPERAR A QUE DPKG ESTÉ DISPONIBLE
# ============================================================
# Evita conflictos con unattended-upgr que bloquea dpkg
# en VPS nuevos. Espera a que se libere el lock antes de
# intentar usar apt-get o instalar paquetes.
wait_for_dpkg() {
    local locks=("/var/lib/dpkg/lock-frontend" "/var/lib/dpkg/lock" "/var/cache/apt/archives/lock")
    local waited=0
    local max_wait=300  # 5 minutos máximo

    while true; do
        local locked=false
        for lock in "${locks[@]}"; do
            if [[ -f "$lock" ]]; then
                # Verificar si el proceso que tiene el lock sigue vivo
                local lock_holder=$(lsof "$lock" 2>/dev/null | grep -v COMMAND | awk '{print $2}' | head -1)
                if [[ -n "$lock_holder" ]] && ps -p "$lock_holder" > /dev/null 2>&1; then
                    locked=true
                    break
                fi
            fi
        done

        if ! $locked; then
            return 0
        fi

        if [[ $waited -ge $max_wait ]]; then
            log_warning "dpkg lock no se liberó después de $max_wait segundos"
            log_info "Continuando de todas formas..."
            return 1
        fi

        if [[ $((waited % 10)) -eq 0 ]]; then
            log_process "Esperando a que se libere dpkg (${waited}s)..."
        fi

        sleep 2
        waited=$((waited + 2))
    done
}

# ============================================================
# FUNCIONES DE CHECKPOINT — Registro de avance de instalación
# Permiten retomar desde el último paso completado si el
# script se interrumpe por cualquier motivo.
# ============================================================

# step_is_done — Verificar si un paso ya fue completado
# Uso: step_is_done "00_precheck"
step_is_done() {
    local step_name="$1"
    [[ -f "${STATE_FILE}" ]] && grep -qx "${step_name}" "${STATE_FILE}"
}

# step_mark_done — Registrar un paso como completado
# Uso: step_mark_done "00_precheck"
step_mark_done() {
    local step_name="$1"
    echo "${step_name}" >> "${STATE_FILE}"
}

# step_reset — Borrar el registro de avance para empezar de cero
# Uso: step_reset
step_reset() {
    rm -f "${STATE_FILE}"
    log_info "Registro de avance eliminado. La próxima ejecución empezará desde el inicio."
}
