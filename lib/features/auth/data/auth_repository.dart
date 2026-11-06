import '../../../core/network/api_client.dart';
import '../models/session_user.dart';

class LoginSession {
  const LoginSession(this.token, this.user, this.expiresIn);
  final String token;
  final SessionUser user;
  final int expiresIn;
}

class AuthRepository {
  AuthRepository(this.api);
  final ApiClient api;
  Future<LoginSession> login(String username, String password) async {
    final json = await api.request(
      'POST',
      'auth/login',
      authenticated: false,
      body: {'username': username.trim(), 'password': password},
    );
    return LoginSession(
      json['accessToken'] as String,
      SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      json['expiresIn'] as int,
    );
  }

  Future<SessionUser> me() async =>
      SessionUser.fromJson(await api.request('GET', 'auth/me'));
  Future<void> logout() async {
    await api.request('POST', 'auth/logout', body: {});
  }

  Future<void> changePassword(String current, String next) async {
    await api.request(
      'POST',
      'auth/change-password',
      body: {'currentPassword': current, 'newPassword': next},
    );
  }
}
