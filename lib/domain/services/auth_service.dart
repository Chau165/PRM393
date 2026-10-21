import '../models/warehouse_app_data.dart';

class AuthService {
  const AuthService();

  AppUser? authenticate(List<AppUser> users, String username, String password) {
    final normalized = username.trim().toLowerCase();
    for (final user in users) {
      if (user.username.toLowerCase() == normalized &&
          user.password == password) {
        return user;
      }
    }
    return null;
  }
}
