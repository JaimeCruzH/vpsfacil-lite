# VPSfacil-lite — Instalación Nativa sin Docker

## Descripción del Proyecto

**VPSfacil-lite** es la versión simplificada de VPSfacil. Instala las mismas aplicaciones pero **directamente en el sistema operativo** como servicios systemd, sin Docker ni Portainer.

**Diferencia clave respecto a VPSfacil:**

| Característica | VPSfacil | VPSfacil-lite |
|----------------|----------|---------------|
| Contenedores | Docker + Portainer | ❌ Sin Docker |
| Gestión de apps | docker-compose | systemd services |
| Proxy HTTPS | Por app (cert en contenedor) | nginx nativo (un solo proxy) |
| Recursos RAM | ~500 MB overhead Docker | Mínimo |
| Complejidad | Mayor | Menor |
| Aislamiento | Contenedores | Procesos nativos |

---

## Infraestructura Objetivo

### VPS
- **OS:** Debian 12 (limpio)
- **CPU:** 2+ cores
- **RAM:** 2 GB mínimo (sin overhead de Docker)
- **Disco:** 20 GB mínimo

### Dominio y DNS
- **DNS:** Cloudflare (DNS-only, sin proxy/CDN)
- **Subdominios:** `*.vpn.DOMAIN` → IP Tailscale

---

## Arquitectura

```
Navegador (con Tailscale activo)
        ↓
Cloudflare DNS → *.vpn.DOMAIN → IP Tailscale (100.x.x.x)
        ↓
Tailscale VPN (WireGuard cifrado)
        ↓
VPS — nginx nativo (HTTPS, cert Let's Encrypt wildcard)
  ├─ files.vpn.DOMAIN   → 127.0.0.1:8080  (File Browser)
  ├─ kopia.vpn.DOMAIN   → 127.0.0.1:51515 (Kopia)
  └─ beszel.vpn.DOMAIN  → 127.0.0.1:8090  (Beszel)
```

**Ventajas:**
- ✅ Sin overhead de Docker (menos RAM, menos complejidad)
- ✅ Un solo nginx gestiona todo el HTTPS
- ✅ Servicios nativos → más fácil de debuggear
- ✅ Misma seguridad: todo privado vía Tailscale VPN
- ✅ Misma arquitectura DNS + Let's Encrypt que VPSfacil

---

## Orden de Instalación (9 pasos, como root)

| Paso | Script | Descripción |
|------|--------|-------------|
| 1 | `00_precheck.sh` | Verificar OS, internet, espacio, instalar dependencias base |
| 2 | `01_create_user.sh` | Crear usuario admin, SSH key, sudo NOPASSWD, directorios |
| 3 | `02_install_firewall.sh` | UFW (sin fix Docker — no aplica aquí) |
| 4 | `03_install_tailscale.sh` | Tailscale VPN, autenticación, obtener IP |
| 5 | `04_setup_dns.sh` | Registros DNS en Cloudflare vía API |
| 6 | `05_setup_certificates.sh` | Cert Let's Encrypt wildcard + configurar nginx |
| 7 | `06_install_filebrowser.sh` | File Browser: binario + systemd + nginx vhost |
| 8 | `07_install_kopia.sh` | Kopia Backup: paquete + systemd + nginx vhost |
| 9 | `08_finalize.sh` | Permisos, hardening SSH, fail2ban, resumen |

---

## Aplicaciones Incluidas (core)

| App | Puerto interno | URL de acceso | Instalación |
|-----|---------------|---------------|-------------|
| File Browser | 8080 | `https://files.vpn.DOMAIN` | Binario GitHub |
| Kopia Backup | 51515 | `https://kopia.vpn.DOMAIN` | Paquete APT oficial |
| Beszel Hub | 8090 | `https://beszel.vpn.DOMAIN` | Binario GitHub |

**Sin Portainer** — no se necesita, los servicios se gestionan con `systemctl`.

---

## Estructura del Proyecto

```
VPSfacil-lite/
├── CLAUDE.md                  # Este archivo
├── setup.sh                   # Script principal
├── .gitignore
│
├── scripts/                   # 9 pasos de instalación
│   ├── 00_precheck.sh
│   ├── 01_create_user.sh
│   ├── 02_install_firewall.sh
│   ├── 03_install_tailscale.sh
│   ├── 04_setup_dns.sh
│   ├── 05_setup_certificates.sh
│   ├── 06_install_filebrowser.sh
│   ├── 07_install_kopia.sh
│   └── 08_finalize.sh
│
├── lib/                       # Funciones reutilizables
│   ├── colors.sh              # Colores ANSI (copiado de VPSfacil)
│   ├── utils.sh               # Utilidades bash (copiado de VPSfacil)
│   ├── config.sh              # Variables globales (adaptado, sin Docker)
│   ├── progress.sh            # Barra de progreso (9 pasos)
│   └── cloudflare_api.sh      # API de Cloudflare DNS (copiado de VPSfacil)
│
└── config/
    └── defaults.conf          # Valores por defecto
```

---

## Estructura de Directorios en el VPS

```
/home/ADMIN_USER/
├── setup.conf                 # Configuración guardada
├── backups/                   # Repositorio Kopia (NO respaldar esto)
└── apps/                      # Datos de apps (esto SÍ se respalda con Kopia)
    ├── certs/                 # Certificado wildcard Let's Encrypt
    │   ├── origin-cert.pem
    │   └── origin-cert-key.pem
    ├── filebrowser/           # Base de datos SQLite de File Browser
    ├── kopia/                 # Configuración y cache de Kopia
    └── beszel/                # Datos de Beszel Hub
```

---

## nginx: Configuración Central

A diferencia de VPSfacil donde cada contenedor maneja su propio TLS, aquí **un único nginx** actúa como proxy HTTPS para todas las apps:

```nginx
# /etc/nginx/sites-available/vpsfacil-lite
server {
    listen 443 ssl;
    server_name files.vpn.DOMAIN;
    ssl_certificate     /home/ADMIN_USER/apps/certs/origin-cert.pem;
    ssl_certificate_key /home/ADMIN_USER/apps/certs/origin-cert-key.pem;
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
# (similar para kopia y beszel)
```

---

## Convenciones de Desarrollo

Idénticas a VPSfacil — ver CLAUDE.md del repositorio padre para referencia completa:
- `set -euo pipefail` en todos los scripts
- Logging con colores: `log_info`, `log_success`, `log_warning`, `log_error`
- `check_root` al inicio de cada script
- `source_config` para cargar variables
- Confirmación antes de acciones destructivas
- Idempotencia: scripts seguros de re-ejecutar

---

## Relación con VPSfacil

Este proyecto es un **desarrollo paralelo e independiente**. Comparte:
- Arquitectura de red (Tailscale + Cloudflare DNS + Let's Encrypt)
- Librerías `lib/` (colors, utils, cloudflare_api)
- Convenciones de código y UX

No comparte:
- Scripts de instalación (todo nativo, sin Docker)
- `lib/portainer_api.sh` (no aplica)
- `lib/nginx_api.sh` (no aplica)

---

## Estado del Proyecto

- [x] Estructura de proyecto creada
- [x] Librerías base copiadas y adaptadas
- [x] Scripts esqueleto de los 9 pasos
- [x] CLAUDE.md documentado
- [ ] Implementación de scripts (en desarrollo)
- [ ] Pruebas en VPS fresco

**Repositorio:** https://github.com/JaimeCruzH/vpsfacil-lite
