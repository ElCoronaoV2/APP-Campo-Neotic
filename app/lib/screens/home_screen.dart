import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import 'cuestionario_screen.dart';
import 'login_screen.dart';

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
  bool _micOk = false;   // permiso + STT disponible


  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final speechOk = await _speech.init();
    await _tts.init();
    if (mounted) {
      setState(() {
        _micOk = speechOk;
  
        _iniciando = false;
      });
    }
  }

  Future<void> _reintentar() async {
    setState(() => _iniciando = true);
    await _iniciar();
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
                // Saludo
                Text(
                  'Hola, ${widget.socio.nombre}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Socio nº ${widget.socio.numSocio}',
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Banner de estado del micrófono
                _buildEstadoMic(),
                const SizedBox(height: 24),

                // Botón iniciar cuestionario
                SizedBox(
                  height: 72,
                  child: ElevatedButton.icon(
                    onPressed: (_iniciando || !_micOk)
                        ? null
                        : () => _iniciarCuestionario(context),
                    icon: _iniciando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.mic, size: 32),
                    label: Text(
                      _iniciando
                          ? 'Comprobando micrófono…'
                          : 'EMPEZAR CUESTIONARIO',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Cerrar sesión
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildEstadoMic() {
    if (_iniciando) {
      return _banner(
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        texto: 'Comprobando permisos de micrófono…',
      );
    }

    if (_speech.isPermissionDenied) {
      return Column(
        children: [
          _banner(
            icon: Icons.mic_off,
            color: Colors.red,
            texto: 'Micrófono desactivado — el cuestionario no puede grabar tu voz.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await openAppSettings();
                    // Al volver de Ajustes reintenta
                    await Future.delayed(const Duration(seconds: 1));
                    _reintentar();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Ir a Ajustes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reintentar,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (!_micOk) {
      return _banner(
        icon: Icons.warning_amber,
        color: Colors.orange,
        texto:
            'Reconocimiento de voz no disponible. Puedes usar el cuestionario en modo teclado.',
        accion: OutlinedButton.icon(
          onPressed: _reintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    // Todo OK
    return _banner(
      icon: Icons.mic,
      color: Colors.green,
      texto: 'Micrófono listo. Habla con claridad.',
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String texto,
    Widget? accion,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(texto,
                    style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 15)),
              ),
            ],
          ),
          if (accion != null) ...[const SizedBox(height: 8), accion],
        ],
      ),
    );
  }
}
