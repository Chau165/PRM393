import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalDataStore {
  Future<String?> loadJson();

  Future<void> saveJson(String value);
}

class SharedPreferencesLocalDataStore implements LocalDataStore {
  SharedPreferencesLocalDataStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const _dataKey = 'warehouse_app_data_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> loadJson() => _preferences.getString(_dataKey);

  @override
  Future<void> saveJson(String value) =>
      _preferences.setString(_dataKey, value);
}
