import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/speech_service.dart';
import '../services/tts_service.dart';
import '../services/update_service.dart';
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
  final UpdateService _updater = UpdateService();

  bool _iniciando = true;
  bool _micOk = false;

  VersionInfo? _update;          // null = sin actualización o fallo de red
  bool _descargando = false;
  double _descargaProgress = 0;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    setState(() => _iniciando = true);
    final speechOk = await _speech.init();
    await _tts.init();
    final info = await _updater.checkUpdate();
    if (mounted) {
      setState(() {
        _micOk = speechOk;
        _update = (info != null && info.hayActualizacion) ? info : null;
        _iniciando = false;
      });
    }
  }

  Future<void> _reintentar() async => _iniciar();

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

  Future<void> _instalarActualizacion() async {
    final info = _update;
    if (info == null) return;
    setState(() { _descargando = true; _descargaProgress = 0; });
    final ok = await _updater.downloadAndInstall(
      info.apkUrl,
      onProgress: (p) => setState(() => _descargaProgress = p),
    );
    if (mounted) {
      setState(() => _descargando = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al descargar la actualización. Inténtalo de nuevo.')),
        );
      }
      // Si ok=true el instalador de Android se ha abierto — el usuario confirma
    }
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
                const SizedBox(height: 24),

                // Banner actualización (si la hay)
                if (_update != null) ...[
                  _bannerActualizacion(_update!),
                  const SizedBox(height: 16),
                ],

                // Banner estado micrófono
                _buildEstadoMic(),
                const SizedBox(height: 24),

                // Botón cuestionario
                SizedBox(
                  height: 72,
                  child: ElevatedButton.icon(
                    onPressed: (_iniciando || !_micOk)
                        ? null
                        : () => _iniciarCuestionario(context),
                    icon: _iniciando
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.mic, size: 32),
                    label: Text(
                      _iniciando ? 'Comprobando…' : 'EMPEZAR CUESTIONARIO',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Cerrar sesión
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

                const SizedBox(height: 12),
                Text(
                  'v${UpdateService.currentVersion}',
                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── BANNER ACTUALIZACIÓN ──────────────────────────────────
  Widget _bannerActualizacion(VersionInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        border: Border.all(color: Colors.amber.shade700),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.system_update, color: Colors.amber.shade800, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nueva versión disponible: ${info.version}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    Text(
                      'Versión actual: ${UpdateService.currentVersion}',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_descargando) ...[
            LinearProgressIndicator(value: _descargaProgress > 0 ? _descargaProgress : null),
            const SizedBox(height: 6),
            Text(
              _descargaProgress > 0
                  ? 'Descargando… ${(_descargaProgress * 100).round()}%'
                  : 'Conectando…',
              style: const TextStyle(fontSize: 13),
            ),
          ] else
            SizedBox(
              height: 44,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _instalarActualizacion,
                icon: const Icon(Icons.download),
                label: const Text('Descargar e instalar', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── BANNER MICRÓFONO ──────────────────────────────────────
  Widget _buildEstadoMic() {
    if (_iniciando) {
      return _banner(
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        texto: 'Comprobando permisos de micrófono…',
      );
    }
    if (_speech.isPermissionDenied) {
      return Column(children: [
        _banner(
          icon: Icons.mic_off,
          color: Colors.red,
          texto: 'Micrófono desactivado — el cuestionario no puede grabar tu voz.',
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await openAppSettings();
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
        ]),
      ]);
    }
    if (!_micOk) {
      return _banner(
        icon: Icons.warning_amber,
        color: Colors.orange,
        texto: 'Voz no disponible. Puedes usar el modo teclado.',
        accion: OutlinedButton.icon(
          onPressed: _reintentar,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    return _banner(icon: Icons.mic, color: Colors.green, texto: 'Micrófono listo.');
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
      child: Column(children: [
        Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(texto,
              style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 15))),
        ]),
        if (accion != null) ...[const SizedBox(height: 8), accion],
      ]),
    );
  }
}
