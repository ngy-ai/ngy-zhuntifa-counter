import 'package:ngy_zhuntifa_counter/data/key_value_store.dart';

/// 测试用的内存存储。
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial])
    : _values = <String, String>{...?initial};

  final Map<String, String> _values;

  String? get snapshot => _values['ngy_zhunti_practice_v1'];

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
