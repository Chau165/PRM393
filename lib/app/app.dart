import 'package:flutter/material.dart';

import '../domain/services/warehouse_app_state.dart';
import '../features/app_shell.dart';
import '../features/auth/login_page.dart';
import 'theme.dart';

class WarehouseApp extends StatelessWidget {
  const WarehouseApp({super.key, required this.state});

  final WarehouseAppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: 'Warehouse Management Demo',
        debugShowCheckedModeBanner: false,
        theme: buildWarehouseTheme(),
        home: state.currentUser == null
            ? LoginPage(state: state)
            : WarehouseShell(state: state, user: state.currentUser!),
      ),
    );
  }
}
