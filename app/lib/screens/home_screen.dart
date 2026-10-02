import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import 'cuestionario_screen.dart';
import 'login_screen.dart';

/// Pantalla de inicio tras el login.
class HomeScreen extends StatefulWidget {
  final Socio socio;
  final AuthService auth;

  const HomeScreen({super.key, required this.socio, required this.auth});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechService _speech = SpeechService();
  final TtsService _tts = TtsService();
  bool _iniciando = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    await _speech.init();
    await _tts.init();
    if (mounted) setState(() => _iniciando = false);
  }

  Future<void> _logout(BuildContext context) async {
    await widget.auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(auth: widget.auth)),
    );
  }

  void _iniciarCuestionario(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CuestionarioScreen(
          socio: widget.socio,
          speech: _speech,
          tts: _tts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voz del Campo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hola, \${widget.socio.nombre}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Socio nº \${widget.socio.numSocio}',
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  height: 72,
                  child: ElevatedButton.icon(
                    onPressed: _iniciando ? null : () => _iniciarCuestionario(context),
                    icon: _iniciando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.mic, size: 32),
                    label: Text(
                      _iniciando ? 'Iniciando micrófono…' : 'EMPEZAR CUESTIONARIO',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('CERRAR SESIÓN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
