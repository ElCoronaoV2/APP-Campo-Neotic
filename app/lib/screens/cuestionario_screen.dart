import 'package:flutter/material.dart';
import '../models/models.dart' as models;
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import 'question_screen.dart';

/// Preguntas MVP hardcodeadas (Fase 7: vendrán de Sheets).
const List<QuestionPrompt> _preguntasMvp = [
  QuestionPrompt(orden: 1, texto: '¿En qué término municipal está la finca?', tipo: 'entidad_pueblo'),
  QuestionPrompt(orden: 2, texto: '¿Cómo se llama la finca?',               tipo: 'entidad_finca'),
  QuestionPrompt(orden: 3, texto: '¿Cuántas hectáreas tiene?',               tipo: 'numero'),
  QuestionPrompt(orden: 4, texto: '¿Qué tipo de tratamiento se ha aplicado?', tipo: 'texto'),
];

class CuestionarioScreen extends StatefulWidget {
  final models.Socio socio;
  final SpeechService speech;
  final TtsService tts;

  const CuestionarioScreen({
    super.key,
    required this.socio,
    required this.speech,
    required this.tts,
  });

  @override
  State<CuestionarioScreen> createState() => _CuestionarioScreenState();
}

class _CuestionarioScreenState extends State<CuestionarioScreen> {
  int _indice = 0;
  final List<QuestionResult> _respuestas = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _irSiguiente());
  }

  Future<void> _irSiguiente() async {
    if (_indice >= _preguntasMvp.length) {
      _mostrarResumen();
      return;
    }
    final pregunta = _preguntasMvp[_indice];
    final resultado = await Navigator.of(context).push<QuestionResult>(
      MaterialPageRoute(
        builder: (_) => QuestionScreen(
          pregunta: pregunta,
          speech: widget.speech,
          tts: widget.tts,
        ),
      ),
    );
    if (!mounted) return;
    if (resultado != null) {
      setState(() {
        _respuestas.add(resultado);
        _indice++;
      });
      _irSiguiente();
    }
    // Si resultado es null (usuario volvió atrás), no avanzamos
  }

  void _mostrarResumen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Cuestionario completado'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _respuestas.asMap().entries.map((e) {
              final p = _preguntasMvp[e.key];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.texto,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(e.value.valor,
                        style: const TextStyle(fontSize: 16)),
                    Text('(${e.value.modoEntrada})',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('VOLVER AL INICIO'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pregunta ${_indice + 1} de ${_preguntasMvp.length}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
