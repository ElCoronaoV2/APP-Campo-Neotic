import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Pantalla placeholder para Fase 2. La funcionalidad del cuestionario
/// llega en Fases 3-7. Muestra saludo personalizado + logout funcional.
class HomeScreen extends StatelessWidget {
  final Socio socio;
  final AuthService auth;

  const HomeScreen({super.key, required this.socio, required this.auth});

  Future<void> _logout(BuildContext context) async {
    await auth.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(auth: auth)),
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
                  'Hola, ${socio.nombre}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sesión iniciada correctamente.',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Socio nº ${socio.numSocio}',
                  style: const TextStyle(fontSize: 14, color: Colors.black45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: const [
                        Icon(Icons.rocket_launch,
                            size: 48, color: Colors.black38),
                        SizedBox(height: 12),
                        Text(
                          'El cuestionario estará disponible\nen la próxima fase (Fase 3).',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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