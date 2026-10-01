# Apps Script backend

## Estructura

```
backend/
├── Code.gs                 Endpoint Web App + handlers
├── appsscript.json         Manifiesto (se crea con `clasp create`)
└── scripts/
    └── transform_municipios.py   Utilidad para generar el JSON de municipios
```

## Despliegue paso a paso

### 1. Login con tu cuenta de Google

```bash
clasp login
```

Abre el navegador, autoriza el acceso.

### 2. Crear proyecto Apps Script

```bash
cd backend
clasp create --type standalone --title "voz-campo-backend"
```

Esto crea un proyecto en tu Drive y un `appsscript.json` local.

### 3. Configurar `Code.gs`

Editar `backend/Code.gs` y rellenar:

```javascript
const SHEET_ID = 'PEGAR_AQUI_EL_ID_DE_LA_GOOGLE_SHEET';
const API_TOKEN = 'CAMBIAR_POR_TOKEN_SEGURO_DE_32_CHARS_MIN';
```

Para obtener el `SHEET_ID`:

1. Crea una Google Sheet nueva con nombre `voz-campo-data`.
2. Crea 4 pestañas: `Registros`, `Socios`, `Fincas_Pueblos`, `Preguntas`.
3. Copia la URL, tiene pinta de:
   `https://docs.google.com/spreadsheets/d/ESTE_ES_EL_ID/edit`
4. Pega el ID en `SHEET_ID`.

Para el `API_TOKEN`, genera uno seguro:

```bash
openssl rand -hex 32
```

### 4. Desplegar

```bash
clasp push
clasp deploy --description "MVP v0.1"
```

Copia la URL del Web App que imprime `clasp deploy` y pégala en `app/lib/services/sheets_api.dart`:

```dart
const String API_BASE_URL = 'https://script.google.com/macros/s/AKfycbw.../exec';
const String API_TOKEN = 'el-mismo-que-en-Code.gs';
```

## Endpoints

### POST `/exec` con body JSON

#### Crear registro

```json
{
  "token": "...",
  "op": "crear_registro",
  "usuario": "2323",
  "fechaHora": "2026-10-01T09:30:00Z",
  "respuestas": {
    "numSocio": "2323",
    "pueblo": "Benigànim",
    "finca": "La Solana",
    "hectareas": 12.5,
    "tipoTratamiento": "Fungicida"
  },
  "metadatosVoz": {
    "pueblo_original_audio": "benigani",
    "confianza_fuzzy": 0.88,
    "modo_entrada": "voz_asistida"
  },
  "coordenadasGps": "38.9912,-0.5234",
  "dispositivo": "Android 14"
}
```

Respuesta:

```json
{ "status": "ok", "id": 154 }
```

### GET `/exec?op=preguntas&token=...`

Devuelve la lista de preguntas del cuestionario cacheable en cliente.

### GET `/exec?op=socios&numSocio=2323&token=...`

Devuelve datos del socio para login (sin PIN, eso lo validamos en local).

### GET `/exec?op=fincas&numSocio=2323&token=...`

Devuelve la lista de fincas del socio (cacheable para fuzzy matching offline).

## Seguridad

- **API_TOKEN** es la única barrera de entrada. Cambiarlo requiere actualizar todos los clientes.
- **HTTPS** lo gestiona Google.
- **LockService** evita que dos socios escribiendo a la vez generen IDs duplicados.
- En **producción** se debería migrar a:
  - Autenticación OAuth por socio,
  - PIN hasheado (bcrypt/argon2) en la columna correspondiente,
  - Certificate pinning en la app.

## Limitaciones conocidas

- Apps Script tiene un timeout de 90 segundos en Web App. Con `LockService.waitLock(30000)` se cubren cuellos de botella normales.
- Cuota: 20.000 ejecuciones/día en cuentas personales. Para 100 socios enviando 20 registros/día cada uno = 2.000 ejecuciones/día. Holgura amplia.
- Si se excede, mover a Cloud Functions (ver `docs/arquitectura.md` → roadmap).