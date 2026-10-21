import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/local/local_data_store.dart';
import 'domain/services/warehouse_app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await WarehouseAppState.create(
    store: SharedPreferencesLocalDataStore(),
  );
  runApp(WarehouseApp(state: state));
}
