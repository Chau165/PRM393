import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

// Browser sessions deliberately remain in memory; refreshing the page requires
// login again. Native platforms use their secure storage, never SharedPreferences.
TokenStore createTokenStore() =>
    kIsWeb ? MemoryTokenStore() : SecureTokenStore();

class MemoryTokenStore implements TokenStore {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}

class SecureTokenStore implements TokenStore {
  static const _key = 'vaxstock.access_token.v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}
