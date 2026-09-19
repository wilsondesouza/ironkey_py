import 'package:flutter/services.dart';

class CryptoBridge {
  static const MethodChannel _channel = MethodChannel('com.ironkey.crypto');

  /// Destrava o cofre derivando a KEK com Argon2id nativo e conferindo a DEK e verifier.
  static Future<bool> unlock({
    required String masterPassword,
    required String configJson,
  }) async {
    try {
      final bool? success = await _channel.invokeMethod<bool>('unlock', {
        'masterPassword': masterPassword,
        'configJson': configJson,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      throw Exception('Falha ao abrir cofre: ${e.message}');
    }
  }

  /// Tranca o cofre e limpa a DEK da memória.
  static Future<void> lock() async {
    try {
      await _channel.invokeMethod('lock');
    } catch (_) {}
  }

  /// Verifica se o cofre está destravado.
  static Future<bool> isUnlocked() async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('isUnlocked');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cifra um registro individual com a DEK ativa usando AES-256-GCM.
  static Future<String> encryptRecord(String plaintext) async {
    try {
      final String? res = await _channel.invokeMethod<String>('encryptRecord', {
        'plaintext': plaintext,
      });
      return res ?? '';
    } on PlatformException catch (e) {
      throw Exception('Erro ao cifrar: ${e.message}');
    }
  }

  /// Decifra um registro individual com a DEK ativa usando AES-256-GCM.
  static Future<String> decryptRecord(String ciphertext) async {
    try {
      final String? res = await _channel.invokeMethod<String>('decryptRecord', {
        'ciphertext': ciphertext,
      });
      return res ?? '';
    } on PlatformException catch (e) {
      throw Exception('Erro ao decifrar: ${e.message}');
    }
  }

  /// Lê e valida um arquivo de entrada de dispositivo (.ikenr).
  static Future<Map<String, dynamic>> readEnrollment({
    required String ikenrJson,
    required String masterPassword,
  }) async {
    try {
      final Map<dynamic, dynamic>? res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'readEnrollment',
        {
          'ikenrJson': ikenrJson,
          'masterPassword': masterPassword,
        },
      );
      if (res == null) throw Exception('Arquivo de entrada inválido.');
      return Map<String, dynamic>.from(res);
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Falha ao importar entrada de dispositivo.');
    }
  }
}
