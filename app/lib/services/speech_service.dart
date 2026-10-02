import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

/// Resultado de una sesión de escucha.
class SpeechResult {
  final String text;
  final bool isFinal;
  SpeechResult({required this.text, required this.isFinal});
}

/// Estados posibles del servicio de voz.
enum SpeechStatus { notInitialized, ready, listening, stopping, unavailable }

/// Servicio de reconocimiento de voz (speech_to_text).
///
/// Uso:
///   1. await init()          — una sola vez al arrancar la app
///   2. await listen(...)     — inicia escucha; callback onResult con cada resultado
///   3. await stop()          — detiene la escucha manualmente
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  SpeechStatus status = SpeechStatus.notInitialized;
  String? lastError;

  // Locales preferidos en orden (es_ES primero, ca_ES valenciano como fallback)
  static const List<String> _preferredLocales = ['es_ES', 'ca_ES', 'es-ES', 'ca-ES'];

  /// Inicializa el motor. Devuelve true si está disponible.
  /// Debe llamarse en initState(), una sola vez.
  Future<bool> init() async {
    final available = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
      debugLogging: kDebugMode,
    );
    status = available ? SpeechStatus.ready : SpeechStatus.unavailable;
    return available;
  }

  bool get isListening => _stt.isListening;
  bool get isReady => status == SpeechStatus.ready || status == SpeechStatus.stopping;

  /// Inicia una sesión de escucha.
  ///
  /// [onResult] — llamado con cada resultado (parcial o final).
  /// [phraseHints] — lista de palabras esperadas para mejorar el reconocimiento
  ///                 (ej: nombres de pueblos para el campo de municipio).
  Future<void> listen({
    required void Function(SpeechResult result) onResult,
    List<String> phraseHints = const [],
  }) async {
    if (!isReady) return;
    lastError = null;
    status = SpeechStatus.listening;

    final localeId = await _resolveLocale();

    await _stt.listen(
      onResult: (r) => onResult(SpeechResult(
        text: r.recognizedWords,
        isFinal: r.finalResult,
      )),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
        localeId: localeId,
      ),
    );
  }

  /// Detiene la escucha activa.
  Future<void> stop() async {
    await _stt.stop();
    status = SpeechStatus.ready;
  }

  /// Cancela sin emitir resultado final.
  Future<void> cancel() async {
    await _stt.cancel();
    status = SpeechStatus.ready;
  }

  void _onError(SpeechRecognitionError error) {
    lastError = error.errorMsg;
    status = SpeechStatus.ready;
  }

  void _onStatus(String s) {
    if (s == 'listening') {
      status = SpeechStatus.listening;
    } else if (s == 'notListening' || s == 'done') {
      status = SpeechStatus.ready;
    }
  }

  /// Intenta usar es_ES; si no está disponible cae al siguiente preferido.
  Future<String?> _resolveLocale() async {
    try {
      final locales = await _stt.locales();
      final available = locales.map((l) => l.localeId).toSet();
      for (final pref in _preferredLocales) {
        if (available.contains(pref)) return pref;
      }
    } catch (_) {}
    return null; // usa el locale del sistema
  }
}