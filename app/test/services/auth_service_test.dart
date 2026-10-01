import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:voz_campo/services/auth_service.dart';

base class InMemorySharedPrefsAsync extends SharedPreferencesAsyncPlatform {
  final Map<String, Object> _store = {};

  @override
  Future<String?> getString(String key, SharedPreferencesOptions options) async =>
      _store[key] as String?;

  @override
  Future<void> setString(
      String key, String value, SharedPreferencesOptions options) async {
    _store[key] = value;
  }

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async =>
      _store[key] as bool?;

  @override
  Future<void> setBool(
      String key, bool value, SharedPreferencesOptions options) async {
    _store[key] = value;
  }

  @override
  Future<double?> getDouble(String key, SharedPreferencesOptions options) async =>
      _store[key] as double?;

  @override
  Future<void> setDouble(
      String key, double value, SharedPreferencesOptions options) async {
    _store[key] = value;
  }

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async =>
      _store[key] as int?;

  @override
  Future<void> setInt(
      String key, int value, SharedPreferencesOptions options) async {
    _store[key] = value;
  }

  @override
  Future<List<String>?> getStringList(
      String key, SharedPreferencesOptions options) async =>
      _store[key] as List<String>?;

  @override
  Future<void> setStringList(String key, List<String> value,
      SharedPreferencesOptions options) async {
    _store[key] = value;
  }

  @override
  Future<void> clear(
      ClearPreferencesParameters parameters,
      SharedPreferencesOptions options) async {
    _store.clear();
  }

  @override
  Future<Map<String, Object>> getPreferences(
      GetPreferencesParameters parameters, SharedPreferencesOptions options) async =>
      Map<String, Object>.from(_store);

  @override
  Future<Set<String>> getKeys(
      GetPreferencesParameters parameters,
      SharedPreferencesOptions options) async =>
      _store.keys.toSet();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPrefsAsync();
  });

  group('AuthService.login', () {
    test('login exitoso persiste sesion y devuelve Socio', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['op'], 'socios');
        expect(request.url.queryParameters['numSocio'], '001');
        expect(request.url.queryParameters['pin'], '1234');
        return http.Response(
          jsonEncode({
            'socio': {
              'numSocio': '001',
              'nombre': 'Test User',
              'activo': true,
              'pin_ok': true,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final auth = AuthService(client: mockClient);
      final socio = await auth.login('001', '1234');

      expect(socio.numSocio, '001');
      expect(socio.nombre, 'Test User');
      expect(socio.activo, isTrue);

      final restored = await auth.checkSession();
      expect(restored, isNotNull);
      expect(restored!.numSocio, '001');
      expect(restored.nombre, 'Test User');
    });

    test('lanza AuthException(socio_not_found) cuando found=false', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'found': false}),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final auth = AuthService(client: mockClient);

      await expectLater(
        () => auth.login('999', '1234'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'socio_not_found'),
        ),
      );
    });

    test('lanza AuthException(socio_inactive) cuando activo=false', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'socio': {
                'numSocio': '002',
                'nombre': 'Inactive',
                'activo': false,
                'pin_ok': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final auth = AuthService(client: mockClient);

      await expectLater(
        () => auth.login('002', '1234'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'socio_inactive'),
        ),
      );
    });

    test('lanza AuthException(pin_incorrect) cuando pin_ok=false', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'socio': {
                'numSocio': '001',
                'nombre': 'Test',
                'activo': true,
                'pin_ok': false,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final auth = AuthService(client: mockClient);

      await expectLater(
        () => auth.login('001', '9999'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'pin_incorrect'),
        ),
      );
    });

    test('lanza AuthException(network_error) cuando http lanza excepcion',
        () async {
      final mockClient = MockClient((_) async {
        throw Exception('socket failed');
      });

      final auth = AuthService(client: mockClient);

      await expectLater(
        () => auth.login('001', '1234'),
        throwsA(
          isA<AuthException>().having((e) => e.code, 'code', 'network_error'),
        ),
      );
    });
  });

  group('AuthService.checkSession + logout', () {
    test('checkSession devuelve null si no hay sesion', () async {
      final auth = AuthService();
      final result = await auth.checkSession();
      expect(result, isNull);
    });

    test('logout borra la sesion persistida', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'socio': {
                'numSocio': '001',
                'nombre': 'Test User',
                'activo': true,
                'pin_ok': true,
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final auth = AuthService(client: mockClient);
      final socio = await auth.login('001', '1234');
      expect(socio.numSocio, '001');

      final before = await auth.checkSession();
      expect(before, isNotNull);

      await auth.logout();

      final after = await auth.checkSession();
      expect(after, isNull);
    });
  });
}