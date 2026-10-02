import 'package:flutter_tts/flutter_tts.dart';

/// Servicio de síntesis de voz (flutter_tts).
///
/// Lee preguntas y confirmaciones en voz alta con volumen alto
/// para entornos con ruido exterior (campo, tractores, viento).
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.5);   // Velocidad normal-lenta, clara en campo
    await _tts.setVolume(1.0);       // Volumen máximo para exterior
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _initialized = true;
  }

  /// Lee [text] en voz alta. Espera a que termine antes de retornar.
  Future<void> speak(String text) async {
    await init();
    await _tts.speak(text);
  }

  /// Detiene cualquier lectura en curso.
  Future<void> stop() async {
    await _tts.stop();
  }
}