import 'dart:async';
import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';

/// Una pregunta del cuestionario, con su texto y tipo.
class QuestionPrompt {
  final int orden;
  final String texto;
  final String tipo; // entidad_pueblo | entidad_finca | numero | texto

  const QuestionPrompt({required this.orden, required this.texto, required this.tipo});
}

/// Resultado que devuelve QuestionScreen al completarse.
class QuestionResult {
  final String preguntaTipo;
  final String valor;
  final String textoOriginal;
  final double confianza;
  final String modoEntrada; // voz | teclado

  const QuestionResult({
    required this.preguntaTipo,
    required this.valor,
    required this.textoOriginal,
    required this.confianza,
    required this.modoEntrada,
  });
}

/// Estados del semáforo de confianza.
enum _SemaforoEstado { idle, grabando, casoA, casoB, casoC }

/// Pantalla de captura de una pregunta por voz con semáforo A/B/C.
///
/// CASO A (confianza >85%): confirmación por voz "He entendido X. ¿Correcto?"
/// CASO B (50-85%): 3 botones grandes con las opciones más probables
/// CASO C (<50% o 2º fallo): teclado / entrada manual libre
class QuestionScreen extends StatefulWidget {
  final QuestionPrompt pregunta;
  final SpeechService speech;
  final TtsService tts;
  /// Sugerencias para phrase hints (ej: lista de pueblos del área)
  final List<String> hints;

  const QuestionScreen({
    super.key,
    required this.pregunta,
    required this.speech,
    required this.tts,
    this.hints = const [],
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  _SemaforoEstado _estado = _SemaforoEstado.idle;
  String _transcripcionActual = '';
  int _intentos = 0;
  bool _speechDisponible = false;

  // Para CASO A
  String _candidatoA = '';

  // Para CASO B — top 3 sugerencias simuladas (en Fase 4 vendrán del FuzzyMatcher)
  List<String> _sugerenciasB = [];

  // Para CASO C — teclado libre
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _iniciarPregunta();
  }

  @override
  void dispose() {
    widget.speech.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _iniciarPregunta() async {
    _speechDisponible = widget.speech.isReady;
    // TTS lee la pregunta en voz alta
    await widget.tts.speak(widget.pregunta.texto);
    if (_speechDisponible) {
      await _grabar();
    } else {
      // Sin STT: ir directo a CASO C
      setState(() => _estado = _SemaforoEstado.casoC);
    }
  }

  Future<void> _grabar() async {
    if (!mounted) return;
    setState(() {
      _estado = _SemaforoEstado.grabando;
      _transcripcionActual = '';
    });

    await widget.speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() => _transcripcionActual = r.text);
        if (r.isFinal && r.text.isNotEmpty) {
          _procesarTranscripcion(r.text);
        }
      },
      phraseHints: widget.hints,
    );

    // Timeout de seguridad: si en 10 s no hay resultado final, paramos
    await Future.delayed(const Duration(seconds: 10));
    if (_estado == _SemaforoEstado.grabando && mounted) {
      await widget.speech.stop();
      if (_transcripcionActual.isEmpty) {
        _aumentarIntentoYDecidirCaso();
      }
    }
  }

  void _procesarTranscripcion(String texto) {
    // En Fase 4 aquí entra el FuzzyMatcher contra municipios.json.
    // Por ahora simulamos confianza según longitud (placeholder).
    final confianza = texto.length > 3 ? 0.88 : 0.45;
    _intentos++;

    if (confianza >= 0.85) {
      // CASO A: alta confianza
      setState(() {
        _candidatoA = texto;
        _estado = _SemaforoEstado.casoA;
      });
      widget.tts.speak('He entendido $texto. ¿Es correcto?');
    } else if (confianza >= 0.50 || _intentos == 1) {
      // CASO B: confianza media o primer intento ambiguo
      setState(() {
        _sugerenciasB = _generarSugerencias(texto);
        _estado = _SemaforoEstado.casoB;
      });
    } else {
      // CASO C: baja confianza o segundo fallo
      _irACasoC();
    }
  }

  void _aumentarIntentoYDecidirCaso() {
    _intentos++;
    if (_intentos >= 2) {
      _irACasoC();
    } else {
      _grabar();
    }
  }

  void _irACasoC() {
    widget.tts.speak('Por favor, escribe la respuesta.');
    setState(() => _estado = _SemaforoEstado.casoC);
  }

  /// Genera sugerencias placeholder para CASO B.
  /// En Fase 4 lo reemplaza FuzzyMatcher.topN(texto, n: 3).
  List<String> _generarSugerencias(String texto) {
    if (widget.hints.isEmpty) return [texto];
    // Devuelve hasta 3 hints que contengan alguna letra del texto
    final lower = texto.toLowerCase();
    final coincidentes = widget.hints
        .where((h) => h.toLowerCase().contains(lower.isNotEmpty ? lower[0] : ''))
        .take(3)
        .toList();
    if (coincidentes.isEmpty) return widget.hints.take(3).toList();
    return coincidentes;
  }

  void _confirmarValor(String valor, {double confianza = 1.0, String modo = 'voz'}) {
    if (!mounted) return;
    Navigator.of(context).pop(QuestionResult(
      preguntaTipo: widget.pregunta.tipo,
      valor: valor,
      textoOriginal: _transcripcionActual.isEmpty ? valor : _transcripcionActual,
      confianza: confianza,
      modoEntrada: modo,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pregunta ${widget.pregunta.orden}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Texto de la pregunta
              Text(
                widget.pregunta.texto,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Panel central según estado
              Expanded(child: _buildCuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCuerpo() {
    switch (_estado) {
      case _SemaforoEstado.idle:
        return const Center(child: CircularProgressIndicator());

      case _SemaforoEstado.grabando:
        return _buildGrabando();

      case _SemaforoEstado.casoA:
        return _buildCasoA();

      case _SemaforoEstado.casoB:
        return _buildCasoB();

      case _SemaforoEstado.casoC:
        return _buildCasoC();
    }
  }

  // ─── GRABANDO ──────────────────────────────────────────────
  Widget _buildGrabando() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic, size: 80, color: Colors.red),
        const SizedBox(height: 16),
        const Text('Escuchando…', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        if (_transcripcionActual.isNotEmpty)
          Text(
            _transcripcionActual,
            style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () async {
              await widget.speech.stop();
              if (_transcripcionActual.isNotEmpty) {
                _procesarTranscripcion(_transcripcionActual);
              } else {
                _aumentarIntentoYDecidirCaso();
              }
            },
            icon: const Icon(Icons.stop),
            label: const Text('Parar', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  // ─── CASO A: ALTA CONFIANZA ────────────────────────────────
  Widget _buildCasoA() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'He entendido:',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        Text(
          _candidatoA,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 64,
                child: ElevatedButton(
                  onPressed: () => _confirmarValor(_candidatoA, confianza: 0.88),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('SÍ', style: TextStyle(fontSize: 24, color: Colors.white)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 64,
                child: OutlinedButton(
                  onPressed: () {
                    _intentos++;
                    if (_intentos >= 2) {
                      _irACasoC();
                    } else {
                      _grabar();
                    }
                  },
                  child: const Text('NO', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── CASO B: CONFIANZA MEDIA ───────────────────────────────
  Widget _buildCasoB() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Selecciona la opción correcta:',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._sugerenciasB.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmarValor(s, confianza: 0.70, modo: 'voz_asistida'),
                  child: Text(s, style: const TextStyle(fontSize: 20)),
                ),
              ),
            )),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _irACasoC,
          child: const Text('Ninguna — escribir manualmente'),
        ),
      ],
    );
  }

  // ─── CASO C: TECLADO ───────────────────────────────────────
  Widget _buildCasoC() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.keyboard, size: 48, color: Colors.black45),
        const SizedBox(height: 16),
        const Text('Escribe la respuesta:', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          autofocus: true,
          style: const TextStyle(fontSize: 20),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Introduce aquí…',
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              _confirmarValor(v.trim(), confianza: 1.0, modo: 'teclado');
            }
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final v = _textController.text.trim();
              if (v.isNotEmpty) _confirmarValor(v, confianza: 1.0, modo: 'teclado');
            },
            child: const Text('CONFIRMAR', style: TextStyle(fontSize: 18)),
          ),
        ),
        if (_speechDisponible) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              _textController.clear();
              _intentos = 0;
              _grabar();
            },
            icon: const Icon(Icons.mic),
            label: const Text('Reintentar por voz'),
          ),
        ],
      ],
    );
  }
}