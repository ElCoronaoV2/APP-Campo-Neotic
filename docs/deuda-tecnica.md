# Deuda Técnica Conocida — voz-campo MVP

Documento vivo de las decisiones de seguridad/diseño aceptadas en el MVP
que se prevé migrar antes de pasar a producción.

## 1. PIN en texto plano en Google Sheets

**Estado actual:** la pestaña `Socios` guarda el PIN en texto plano
(columna `PIN`). El backend `buscarSocio()` lo compara con `===` directamente.

**Riesgo:** cualquier persona con acceso a la Google Sheet ve los PINs
de todos los socios.

**Mitigación MVP:** acceso a la Sheet restringido al admin (sergioibernalfp@gmail.com).
Token API requerido para cualquier llamada desde la app.

**Plan de migración:**
- Hashear PIN con bcrypt/argon2 en la columna (factor de coste ≥ 10).
- Migración no destructiva: si encuentra PIN en claro, lo re-hashea la primera vez.
- Tiempo estimado: 30 minutos cuando se decida.

## 2. API_TOKEN embebido en el cliente

**Estado actual:** el token `458bc7c...` está hardcoded en
`lib/services/api_config.dart` Y en `backend/Code.gs`. Se envía en cada
request como query param `token=...`.

**Riesgo:** trivial de extraer del APK; permite a cualquiera con el token
inyectar datos en la Sheet.

**Mitigación MVP:** la app está en piloto privado, no en tienda. Solo
distribución directa por WhatsApp/email a socios.

**Plan de migración:**
- Migrar backend de Apps Script a Cloud Functions o Cloud Run
  (Node.js/Express) con OAuth por socio.
- Token de cliente OAuth con refresh.
- Tiempo estimado: 1-2 semanas.

## 3. Login online-only

**Estado actual:** `AuthService.login()` requiere conexión para validar contra
el backend. Sin internet → no se puede usar la app.

**Riesgo:** en zonas rurales sin cobertura el socio no puede iniciar sesión.

**Mitigación MVP:** se acepta como limitación del MVP; el caso de uso principal
prevé conexión (los socios están en zonas con datos móviles).

**Plan de migración:**
- Cachear la lista de Socios al instalar la app (datos no sensibles: nombre,
  numSocio, pueblos habituales, hash del PIN).
- Permitir login offline contra el cache con verificación del hash de PIN
  localmente.
- Sincronización periódica del cache cuando haya cobertura.
- Tiempo estimado: 2-3 días (incluye migración a hashing offline-safe).

## 5. PIN viaja como query param en GET

**Estado actual:** `GET ?op=socios&numSocio=X&pin=Y&token=...` envía el PIN
en la URL.

**Riesgo:** el query string puede quedar en logs de proxy/analytics.

**Mitigación MVP:** HTTPS cifra el tráfico en tránsito; no hay proxy intermedio
en la práctica para llamadas directas a `script.google.com`.

**Plan de migración:**
- Mover a POST con body JSON cuando se migre el backend (ver §2).
- Tiempo estimado: incluido en la migración a Cloud Functions.

## 6. Sesión local sin expiración

**Estado actual:** la sesión persiste hasta que el socio la cierre
explícitamente. No hay TTL ni revocación remota.

**Riesgo:** un dispositivo robado/perdido mantiene la sesión activa.

**Mitigación MVP:** el dispositivo Android tiene bloqueo de pantalla habitual
del socio; la app asume que el dueño del dispositivo es el socio legítimo.

**Plan de migración:**
- TTL de 7 días con auto-renovación al abrir la app.
- Botón "Cerrar sesión en todos mis dispositivos" en una futura pantalla de
  perfil.
- Tiempo estimado: 1 día.

## 7. Sin gestión de estado global (Provider/Riverpod)

**Estado actual:** `AuthService` se instancia en `AuthGate` y se pasa por
constructor a LoginScreen y HomeScreen.

**Riesgo:** cuando en Fase 3+ se añadan más pantallas compartiendo estado
(cuestionario, cola offline, sync), el patrón actual será tedioso.

**Plan de migración:**
- Introducir `provider` o `riverpod` cuando la app tenga ≥4 pantallas.
- Tiempo estimado: 1-2 horas.

## 8. Datos del dispositivo sin encriptar en SharedPreferences

**Estado actual:** SharedPreferences nativo de Android almacena en
`/data/data/com.vozcampo.voz_campo/shared_prefs/` en texto claro.

**Riesgo:** con root en el dispositivo, se pueden leer `session_numSocio`
y `session_nombre`.

**Mitigación MVP:** la sesión no contiene credenciales (solo numSocio y nombre),
y la app no es high-value target.

**Plan de migración:**
- Usar `flutter_secure_storage` para datos de sesión (cifrado con Keystore
  de Android / Keychain de iOS).
- Tiempo estimado: 1 hora.

## Resumen de prioridades

| # | Item | Esfuerzo | Prioridad |
|---|------|----------|-----------|
| 1 | Hash de PIN | Bajo | Media |
| 2 | Backend real (Cloud Functions) | Alto | Alta (antes de producción) |
| 4 | Login offline | Medio | Media |
| 5 | POST en lugar de GET | Incluido en #2 | — |
| 6 | TTL de sesión | Bajo | Baja |
| 7 | Provider/Riverpod | Bajo | Baja (cuando crezca la app) |
| 8 | Almacenamiento seguro | Bajo | Media |

El más crítico antes de cualquier distribución más allá del piloto es el
**#2** (backend real). El resto puede vivir con el MVP durante el piloto.