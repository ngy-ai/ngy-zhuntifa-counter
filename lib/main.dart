import 'package:flutter/material.dart';

import 'app.dart';
import 'data/practice_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = PracticeStore();
  await store.load();
  runApp(ZhuntiCounterApp(store: store));
}
