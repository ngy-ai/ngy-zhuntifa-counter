import 'package:shared_preferences/shared_preferences.dart';

/// 最小键值存储接口，便于替换实现（例如测试时使用内存实现）。
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}

/// 基于 shared_preferences 的实现。
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore([SharedPreferencesAsync? preferences])
    : _prefs = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}
