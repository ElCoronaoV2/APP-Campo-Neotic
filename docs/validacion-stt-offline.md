# Validación del Riesgo STT Offline

## El problema

La app promete "funcionar sin cobertura en el campo". Pero el reconocimiento de voz nativo (Speech-to-Text del dispositivo) puede **requerir internet** si el paquete de idioma offline no está descargado previamente.

- **Android (Google Speech Services):** requiere descargar el paquete de idioma. Por defecto solo se baja cuando el usuario lo usa la primera vez con conexión. Si nunca lo ha descargado, intentará hacerlo online y fallará sin red.
- **iOS (Apple Dictation):** desde iOS 17, dictation descarga modelos por idioma. Comportamiento similar.

## Checklist antes del piloto

### En el dispositivo de prueba (Android)

- [ ] **Verificar paquete offline instalado:**
  `Ajustes → Sistema → Idiomas e introducción por voz → Reconocimiento de voz sin conexión → Español (España)` debe estar descargado (no solo "Disponible").
- [ ] **Probar STT en modo avión con paquete descargado:**
  - Activar modo avión.
  - Abrir la app → pulsar para hablar → decir "benigànim".
  - Debe transcribir correctamente.
- [ ] **Probar STT en modo avión SIN paquete descargado:**
  - Borrar el paquete offline.
  - Repetir la prueba anterior.
  - Comprobar que el plugin `speech_to_text` devuelve error `network_required` (o equivalente).
- [ ] **Implementar detección y mensaje al usuario:**
  En `SpeechService.listen()` capturar el error y mostrar mensaje: *"Descarga el paquete de voz español (Ajustes > Idiomas) para usar la app sin conexión."*

### En iPhone de prueba (si hay)

- [ ] Verificar en `Ajustes → General → Teclado → Dictado` que el modelo de español esté descargado.
- [ ] Repetir pruebas de modo avión con y sin modelo.

## Mitigación (ya integrada en el diseño)

1. **Onboarding explícito:** al instalar la app por primera vez con cobertura, guiar al usuario para descargar el paquete offline. Texto sugerido: *"Para usar la app en zonas sin cobertura, descarga el paquete de voz español. Tarda ~10 MB."*
2. **Fallback táctil obligatorio:** tras 2 intentos fallidos de voz en una pregunta, la pantalla pasa automáticamente al modo teclado/buscador (CASO C del semáforo). Esto NO depende del estado offline del STT.
3. **Detección proactiva:** al iniciar la app, intentar un STT corto de prueba. Si falla por falta de paquete, recomendar descarga.

## Comportamiento esperado durante el piloto

| Escenario | Resultado esperado |
|---|---|
| Cobertura + paquete offline instalado | STT funciona, fuzzy matching corrige, todo OK |
| Cobertura + paquete NO instalado | STT funciona (descarga on-the-fly), fuzzy matching OK |
| Sin cobertura + paquete offline instalado | STT funciona offline, fuzzy matching OK → ideal |
| Sin cobertura + paquete NO instalado | STT falla → tras 2 intentos, fallback táctil |
| Sin cobertura + modo teclado | Teclado predictivo contra JSON cacheado funciona OK |

El peor caso (sin cobertura + sin paquete) **no bloquea al usuario**, porque el fallback ya estaba previsto en el documento técnico original (sección 4, CASO C).

## Datos a recoger durante el piloto

Para cada socio piloto:

- [ ] Modelo de dispositivo y versión de SO.
- [ ] ¿Tenía el paquete offline descargado antes del piloto?
- [ ] ¿Cuántas respuestas pudo completar por voz sin ayuda?
- [ ] ¿Cuántas veces tuvo que recurrir al teclado?
- [ ] ¿Errores de reconocimiento sobre pueblos/fincas concretos? (anotar transcripción cruda vs esperado)

Si el ratio de respuestas por voz cae por debajo del 70%, considerar:
- (i) Reentrenar a los usuarios en el paquete offline,
- (iii) Subir variantes fonéticas al JSON de municipios,
- (iii) Pasar a Google Cloud Speech-to-Text con coste por minuto.

## Cambios en código relacionados

- `app/lib/services/speech_service.dart` (próxima fase): capturar `SpeechRecognitionError.code == 'error_network'` y mostrar mensaje al usuario.
- `app/lib/services/fuzzy_matcher.dart` (próxima fase): incluir el `confianza` en el payload para auditoría posterior.