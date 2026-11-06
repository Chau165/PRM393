import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';

import 'app/auth_app.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_store.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const configuredUrl = String.fromEnvironment('API_BASE_URL');
  final defaultUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:5109/api/v1/'
      : 'http://localhost:5109/api/v1/';
  final url = configuredUrl.isEmpty ? defaultUrl : configuredUrl;
  if (kReleaseMode && Uri.parse(url).scheme != 'https') {
    throw StateError('Release builds require an HTTPS API_BASE_URL.');
  }
  final auth = AuthController(
    repository: AuthRepository(ApiClient(baseUrl: url)),
    tokens: createTokenStore(),
  );
  runApp(VaxStockAuthApp(auth: auth));
  await auth.restore();
}
