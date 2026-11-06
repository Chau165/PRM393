import 'package:flutter/material.dart';

import '../features/auth/state/auth_controller.dart';
import '../features/auth/server_auth_page.dart';
import '../features/server_shell.dart';
import 'theme.dart';

class VaxStockAuthApp extends StatelessWidget {
  const VaxStockAuthApp({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VaxStock',
    debugShowCheckedModeBanner: false,
    theme: buildWarehouseTheme(),
    home: AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        switch (auth.status) {
          case SessionStatus.initializing:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case SessionStatus.restoreFailed:
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(auth.error ?? 'Không thể khôi phục phiên.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: auth.busy ? null : auth.restore,
                        child: const Text('Thử lại'),
                      ),
                      TextButton(
                        onPressed: auth.busy ? null : auth.discardLocalSession,
                        child: const Text('Xóa phiên trên thiết bị'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          case SessionStatus.signedOut:
            return ServerLoginPage(auth: auth);
          case SessionStatus.signedIn:
            return ServerShell(
              key: ValueKey('session.${auth.user!.id}'),
              auth: auth,
            );
        }
      },
    ),
  );
}
