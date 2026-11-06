import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_repository.dart';
import '../models/session_user.dart';

enum SessionStatus { initializing, signedOut, signedIn, restoreFailed }

class AuthController extends ChangeNotifier {
  AuthController({required this.repository, required this.tokens}) {
    repository.api.onUnauthorized = _unauthorized;
  }
  final AuthRepository repository;
  final TokenStore tokens;
  SessionStatus status = SessionStatus.initializing;
  SessionUser? user;
  bool busy = false;
  String? error;
  String? notice;
  Timer? _expiry;
  bool _disposed = false;
  Future<void> _storageQueue = Future.value();

  Future<void> _store(Future<void> Function() operation) {
    final task = _storageQueue.then((_) => operation());
    _storageQueue = task.catchError((Object _) {});
    return task;
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    error = null;
    status = SessionStatus.initializing;
    _emit();
    try {
      final token = await tokens.read();
      if (token == null) {
        status = SessionStatus.signedOut;
        return;
      }
      repository.api.token = token;
      user = await repository.me();
      if (repository.api.token != token) return;
      status = SessionStatus.signedIn;
      _scheduleExpiry(token);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearSession();
      } else {
        error = e.message;
        status = SessionStatus.restoreFailed;
      }
    } catch (_) {
      error = 'Không thể đọc hoặc khôi phục phiên. Vui lòng thử lại.';
      status = SessionStatus.restoreFailed;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> login(String username, String password) async {
    if (busy) return;
    if (username.trim().isEmpty || password.isEmpty) {
      error = 'Nhập tên đăng nhập và mật khẩu.';
      _emit();
      return;
    }
    busy = true;
    error = null;
    notice = null;
    _emit();
    try {
      final session = await repository.login(username, password);
      await _store(() => tokens.write(session.token));
      repository.api.token = session.token;
      user = session.user;
      status = SessionStatus.signedIn;
      _scheduleExpiry(session.token);
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Không thể lưu phiên đăng nhập an toàn. Vui lòng thử lại.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> refreshUser() async {
    if (busy) return;
    busy = true;
    error = null;
    _emit();
    try {
      final token = repository.api.token;
      final latest = await repository.me();
      if (token == repository.api.token && token != null) user = latest;
    } on ApiException catch (e) {
      if (e.statusCode != 401) error = e.message;
    } catch (_) {
      error = 'Không thể cập nhật thông tin tài khoản.';
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> logout() async {
    if (busy) return;
    busy = true;
    error = null;
    _emit();
    try {
      await repository.logout();
      notice = 'Đã đăng xuất mọi phiên của tài khoản.';
    } on ApiException catch (e) {
      notice = e.statusCode == 401 ? 'Phiên đã kết thúc.' : 'Đã thoát trên thiết bị này; chưa xác nhận đăng xuất các phiên khác.';
    } catch (_) {
      notice = 'Đã thoát trên thiết bị này; chưa xác nhận thu hồi phiên trên máy chủ.';
    } finally {
      await _clearSession();
      busy = false;
      _emit();
    }
  }

  Future<bool> changePassword(String current, String next) async {
    if (busy) return false;
    busy = true;
    error = null;
    _emit();
    try {
      await repository.changePassword(current, next);
      notice = 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.';
      await _clearSession();
      return true;
    } on ApiException catch (e) {
      if (e.statusCode != 401) error = e.message;
      return false;
    } catch (_) {
      error = 'Chưa xác nhận được kết quả đổi mật khẩu. Vui lòng kiểm tra lại phiên.';
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> discardLocalSession() async {
    await _clearSession();
    error = null;
    _emit();
  }

  void _unauthorized(String rejectedToken) {
    if (repository.api.token != rejectedToken) return;
    notice = 'Phiên đã hết hạn hoặc bị thu hồi. Vui lòng đăng nhập lại.';
    unawaited(_clearSession().then((_) => _emit()));
  }

  Future<void> _clearSession() async {
    _expiry?.cancel();
    repository.api.token = null;
    user = null;
    status = SessionStatus.signedOut;
    try {
      await _store(tokens.clear);
    } catch (_) {
      notice = 'Không thể xóa phiên đã lưu. Hãy thử đăng xuất lại khi kết nối được máy chủ.';
    }
  }

  void _scheduleExpiry(String token) {
    _expiry?.cancel();
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(token.split('.')[1]))),
      ) as Map<String, dynamic>;
      final expires = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
      );
      final delay = expires.difference(DateTime.now());
      _expiry = Timer(
        delay.isNegative ? Duration.zero : delay,
        () => _unauthorized(token),
      );
    } catch (_) {
      // Expiry parsing is only a UI aid, never authentication; BE validates JWT.
    }
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _expiry?.cancel();
    repository.api.onUnauthorized = null;
    repository.api.close();
    super.dispose();
  }
}
