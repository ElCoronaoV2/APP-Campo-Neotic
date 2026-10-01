# voz-campo

App móvil de toma de datos por voz con normalización inteligente para entornos agrícolas (cooperativa).

## Arquitectura

```
APP MÓVIL (Flutter)  ──HTTPS JSON──▶  Google Apps Script  ──▶  Google Sheets
   - Push-to-talk                                  ▲
   - Fuzzy matching (Levenshtein)                  │
   - Cola offline (SQLite)                        └── Web App doPost/doGet
   - Reconocimiento de voz nativo (gratis)
```

Más detalle en [`docs/arquitectura.md`](docs/arquitectura.md).

## Estructura del repo

```
voz-campo/
├── app/            Proyecto Flutter (Android e iOS)
├── backend/        Google Apps Script (Code.gs) versionado con clasp
│   └── scripts/     Scripts auxiliares (transform_municipios.py)
└── docs/           Documentación funcional y de operaciones
```

## Setup (primera vez)

### Requisitos

- WSL 2 con Debian (o cualquier Linux x86_64)
- Flutter 3.35+ (`/opt/flutter` si seguiste el setup por defecto)
- Node.js 20+ y clasp (`npm install -g @google/clasp`)
- Python 3.13+
- Cuenta de Google (para Apps Script y Google Sheets)

### Instalación del toolchain (solo Debian virgen)

Si acabas de instalar Debian en WSL, ejecuta:

```bash
# Herramientas base
sudo apt-get update && sudo apt-get install -y curl xz-utils unzip

# Node 20 LTS
curl -fsSL https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz \
  | sudo tar -xJ -C /opt/node --strip-components=1
sudo ln -sf /opt/node/bin/node /usr/local/bin/node
sudo ln -sf /opt/node/bin/npm /usr/local/bin/npm

# Flutter 3.35.5 stable
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.35.5-stable.tar.xz \
  | sudo tar -xJ -C /opt
echo 'export PATH="/opt/flutter/bin:/opt/node/bin:$PATH"' >> ~/.bashrc

# clasp (CLI de Apps Script)
sudo npm install -g @google/clasp

# git safe directory para el repo de Flutter
git config --global --add safe.directory /opt/flutter
```

### Inicialización del proyecto

```bash
# 1. Crear estructura y proyecto Flutter
flutter create --platforms=android,ios --org com.vozcampo --project-name voz_campo app/

# 2. Instalar dependencias
cd app && flutter pub get

# 3. Generar municipios.json a partir de tu dataset
python3 ../backend/scripts/transform_municipios.py \
  /ruta/a/municipios_espana.json \
  assets/data/municipios.json

# 4. Verificar que compila
flutter analyze
```

### Despliegue del backend (Apps Script)

```bash
# 1. Login con tu cuenta de Google (abre navegador)
cd backend
clasp login

# 2. Editar Code.gs y rellenar SHEET_ID y API_TOKEN
#    SHEET_ID: ID de tu Google Sheet (parte entre /d/ y /edit)
#    API_TOKEN: token secreto de 32+ caracteres

# 3. Crear proyecto Apps Script
clasp create --type standalone --title "voz-campo-backend"

# 4. Desplegar
clasp push
clasp deploy --description "MVP v0.1"
```

Tras `clasp deploy` copia la URL del Web App que imprime (formato `https://script.google.com/macros/s/AKfy.../exec`) y pégala en `app/lib/services/sheets_api.dart` como `API_BASE_URL`.

### Compilar APK (requiere Android SDK)

```bash
# Instalar Android SDK (solo la primera vez)
sudo apt install -y android-sdk
# Aceptar licencias
flutter doctor --android-licenses

# Generar APK de release
flutter build apk --release
# APK en build/app/outputs/flutter-apk/app-release.apk
```

## Estado del proyecto

**MVP** (alcance acotado, ~10-14 días de desarrollo tras tener el toolchain listo):

- [x] Repositorio y proyecto Flutter inicializados
- [x] Dependencias instaladas y verificadas (`flutter analyze` limpio)
- [x] Dataset de municipios transformado (8.131 municipios de toda España)
- [x] Backend Apps Script con LockService, token API y CRUD básico
- [x] Modelos de datos compartidos (Socio, Pregunta, Registro, Municipio, Finca)
- [ ] Pantalla de login (Nº socio + PIN)
- [ ] Push-to-talk con `speech_to_text` + `flutter_tts`
- [ ] Motor de fuzzy matching con semáforo A/B/C
- [ ] Cola sin conexión con `sqflite` + sincronización
- [ ] Cuestionario end-to-end (4 preguntas)
- [ ] APK firmado para piloto

Fuera del MVP (fase 2, ~4-6 semanas adicionales):

- Publicación en Google Play / App Store
- Cuestionario 100% dinámico desde Sheets
- Desempate por GPS en fuzzy matching
- Parsing inteligente de números hablados
- Hardening de seguridad (JWT, certificate pinning)
- Soporte iOS

Ver [`docs/arquitectura.md`](docs/arquitectura.md) para el detalle completo de cada fase.

## Licencia y datos

- El dataset `municipios_espana.json` pertenece al usuario y se mantiene fuera del repo.
- El dataset transformado `app/assets/data/municipios.json` se regenera desde el original con `transform_municipios.py` y está incluido en el APK.
- Las fincas son datos privados de cada socio: viven en la pestaña `Fincas_Pueblos` de Sheets y se descargan/cachean en runtime, nunca en el APK.