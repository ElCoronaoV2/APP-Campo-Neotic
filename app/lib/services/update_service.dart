import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'api_config.dart';

/// Información de una versión disponible.
class VersionInfo {
  final String version;
  final String apkUrl;
  final bool hayActualizacion;

  const VersionInfo({
    required this.version,
    required this.apkUrl,
    required this.hayActualizacion,
  });
}

/// Servicio de actualizaciones OTA (over-the-air) vía Google Drive + Apps Script.
///
/// Flujo:
///   1. checkUpdate() → compara versión instalada con la remota
///   2. Si hay actualización: downloadAndInstall() descarga el APK y lanza el instalador
class UpdateService {
  final http.Client client;

  UpdateService({http.Client? client}) : client = client ?? http.Client();

  /// Versión del APK instalado actualmente. Debe coincidir con pubspec.yaml version.
  static const String currentVersion = '1.0.3';

  /// Comprueba si hay una versión más nueva disponible en el servidor.
  /// Devuelve null si no hay conexión o falla la llamada.
  Future<VersionInfo?> checkUpdate() async {
    try {
      final uri = ApiConfig.buildUri({'op': 'version'});
      final response = await client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final remoteVersion = data['version']?.toString() ?? '';
      final apkUrl = data['apk_url']?.toString() ?? '';
      final hayActualizacion = remoteVersion.isNotEmpty &&
          apkUrl.isNotEmpty &&
          _isNewerVersion(remoteVersion, currentVersion);
      return VersionInfo(
        version: remoteVersion,
        apkUrl: apkUrl,
        hayActualizacion: hayActualizacion,
      );
    } catch (_) {
      return null;
    }
  }

  /// Descarga el APK desde [apkUrl] y lanza el instalador del sistema.
  /// Devuelve true si la descarga fue exitosa (la instalación la confirma el usuario).
  Future<bool> downloadAndInstall(String apkUrl,
      {void Function(double progress)? onProgress}) async {
    try {
      final dir = await getTemporaryDirectory();
      final apkFile = File('${dir.path}/voz-campo-update.apk');

      // Descarga con progreso
      final request = http.Request('GET', Uri.parse(apkUrl));
      final streamed = await client.send(request);
      final total = streamed.contentLength ?? 0;
      var received = 0;
      final sink = apkFile.openWrite();
      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();

      // Lanzar instalador nativo de Android
      await _launchInstaller(apkFile.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Invoca el intent de instalación de APK vía MethodChannel.
  Future<void> _launchInstaller(String filePath) async {
    const channel = MethodChannel('com.vozcampo.voz_campo/installer');
    await channel.invokeMethod('installApk', {'path': filePath});
  }

  /// Compara semver: devuelve true si [remote] > [current].
  bool _isNewerVersion(String remote, String current) {
    final r = _parseVersion(remote);
    final c = _parseVersion(current);
    for (int i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  List<int> _parseVersion(String v) {
    final parts = v.replaceAll(RegExp(r'[^0-9.]'), '').split('.');
    return List.generate(3, (i) => i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0);
  }
}