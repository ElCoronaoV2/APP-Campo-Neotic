# Arquitectura

## Diagrama

```
┌─────────────────────────────────────────────────────────────┐
│                 APP MÓVIL (Flutter)                         │
│                                                             │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  Login   │──▶│ Cuestionario │──▶│   Resumen    │       │
│  │ Nº+PIN   │    │  por voz     │    │  + Enviar   │       │
│  └────┬─────┘    └──────┬───────┘    └──────┬───────┘       │
│       │                 │                    │              │
│       ▼                 ▼                    ▼              │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────┐        │
│  │   Auth   │    │  Speech +    │    │   Sheets     │        │
│  │ Service  │    │   Fuzzy      │    │   API        │        │
│  └────┬─────┘    └──────┬───────┘    └──────┬───────┘        │
│       │                 │                   │               │
│       └────────────┬────┴───────────────────┘               │
│                    ▼                                        │
│            ┌───────────────┐                                │
│            │ Offline Queue │  sqflite                       │
│            │  (SQLite)     │                                │
│            └───────────────┘                                │
└──────────────────────────┬───────────────────────────────────┘
                           │ HTTPS POST JSON
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   GOOGLE APPS SCRIPT                         │
│                                                             │
│  • doPost(token, op=crear_registro, payload) → escribe fila  │
│  • doGet(op=preguntas|socios|fincas) → lectura              │
│  • LockService.getScriptLock() para concurrencia            │
│  • API_TOKEN validado en cada llamada                       │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                  GOOGLE SHEETS                              │
│                                                             │
│  • Registros (filas nuevas por cada envío de la app)        │
│  • Socios (cache local para login offline)                 │
│  • Fincas_Pueblos (cache local para fuzzy matching offline) │
│  • Preguntas (catálogo que lee la app al arrancar)          │
└─────────────────────────────────────────────────────────────┘
```

## Stack

| Capa | Tecnología | Por qué |
|---|---|---|
| App móvil | Flutter 3.35 (Dart 3.9) | Una sola base, libs maduras de voz |
| Voz → texto | Plugin nativo del dispositivo (Google/Android, Apple/iOS) | Sin coste por uso |
| Texto → voz | `flutter_tts` | Volumen alto, configurable |
| Fuzzy matching | `string_similarity` (Levenshtein) + variantes JSON precargadas | Resuelve ruido, acento, valencianismos |
| Persistencia local | `sqflite` (cola offline) + `shared_preferences` (token) | Estándar Flutter, robusto |
| Backend | Google Apps Script + Google Sheets | Sin servidor, gratis, integrable con herramientas ofimáticas |
| Sincronización | `connectivity_plus` + retries | Reanudar cola al recuperar señal |

## Datos que envía la app

```json
{
  "token": "SECURE_APP_TOKEN_9876",
  "op": "crear_registro",
  "usuario": "2323",
  "fechaHora": "2026-10-01T09:30:00",
  "coordenadasGps": "38.9912,-0.5234",
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
  "dispositivo": "Android 14"
}
```

## Estructura de la Google Sheet

### Pestaña `Registros`

| Columna | Tipo | Ejemplo |
|---|---|---|
| ID | int (correlativo) | 154 |
| FechaHora | ISO 8601 | 2026-10-01T09:30:00 |
| Usuario | str | "2323" |
| NumSocio | str | "2323" |
| Pueblo | str (normalizado) | "Benigànim" |
| Finca | str (normalizado) | "La Solana" |
| Hectareas | num | 12.5 |
| TipoTratamiento | str | "Fungicida" |
| TextoOriginalPueblo | str (audio crudo) | "benigani" |
| TextoOriginalFinca | str | "" |
| ConfianzaFuzzy | num 0-1 | 0.88 |
| ModoEntrada | str | "voz_asistida" |
| CoordenadasGps | str | "38.9912,-0.5234" |
| Dispositivo | str | "Android 14" |
| Estado | str | "Validado" |

### Pestaña `Socios`

| Columna | Tipo | Notas |
|---|---|---|
| NumSocio | str (PK) | |
| Nombre | str | |
| PIN | str | Hasheado en producción |
| PueblosHabituales | str (separados por ;) | Para priorizar en fuzzy |
| Activo | "Si"/"No" | |

### Pestaña `Fincas_Pueblos`

| Columna | Tipo | Notas |
|---|---|---|
| NombreOficial | str (PK) | |
| Variantes | str (alias separados por ;) | "xativa;jativa;chativa" |
| NumSocio | str o "TODOS" | Propietario |

### Pestaña `Preguntas`

| Columna | Tipo | Notas |
|---|---|---|
| Orden | int | |
| Texto | str | Lo que lee la app |
| Tipo | enum | `entidad_pueblo`, `entidad_finca`, `numero`, `opcion`, `texto` |
| Obligatoria | "Si"/"No" | |

## Semáforo de fuzzy matching

| Score Levenshtein | Acción |
|---|---|
| > 85% | Confirmación por voz: "He entendido X. ¿Correcto?" → "Sí" avanza |
| 50-85% | 3 botones grandes con las opciones top-3 |
| < 50% o 2º fallo | Teclado / buscador predictivo |

Umbrales definidos en `app/lib/services/fuzzy_matcher.dart` (constantes `UMBRAL_ALTA` y `UMBRAL_MEDIA`).