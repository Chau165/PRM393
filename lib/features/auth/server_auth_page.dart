import 'package:flutter/material.dart';

import 'state/auth_controller.dart';

class ServerLoginPage extends StatefulWidget {
  const ServerLoginPage({super.key, required this.auth});
  final AuthController auth;
  @override
  State<ServerLoginPage> createState() => _ServerLoginPageState();
}

class _ServerLoginPageState extends State<ServerLoginPage> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!widget.auth.busy && _form.currentState!.validate()) {
      widget.auth.login(_username.text, _password.text);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.vaccines_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'VaxStock',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng nhập để tiếp tục',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('server.login.username'),
                      controller: _username,
                      enabled: !widget.auth.busy,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                        counterText: '',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên đăng nhập.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('server.login.password'),
                      controller: _password,
                      enabled: !widget.auth.busy,
                      obscureText: _obscure,
                      maxLength: 128,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        counterText: '',
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Nhập mật khẩu.' : null,
                    ),
                    if (widget.auth.error != null)
                      _Message(widget.auth.error!, error: true),
                    if (widget.auth.notice != null)
                      _Message(widget.auth.notice!),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('server.login.submit'),
                      onPressed: widget.auth.busy ? null : _submit,
                      child: widget.auth.busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đăng nhập'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SessionAccountPage extends StatefulWidget {
  const SessionAccountPage({
    super.key,
    required this.auth,
    this.embedded = false,
  });
  final AuthController auth;
  final bool embedded;
  @override
  State<SessionAccountPage> createState() => _SessionAccountPageState();
}

class _SessionAccountPageState extends State<SessionAccountPage> {
  bool _changingPassword = false;
  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final user = auth.user!;
    final role = switch (user.role) {
      'Admin' => 'Quản trị viên',
      'QualityManager' => 'Quản lý chất lượng',
      _ => 'Nhân viên kho',
    };
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('VaxStock'),
              actions: [
                IconButton(
                  tooltip: 'Cập nhật thông tin',
                  onPressed: auth.busy ? null : auth.refreshUser,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  key: const ValueKey('server.logout'),
                  tooltip: 'Đăng xuất mọi phiên',
                  onPressed: auth.busy ? null : auth.logout,
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Xin chào, ${user.fullName}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('${user.username} · $role'),
                if (auth.busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (auth.error != null) _Message(auth.error!, error: true),
                const SizedBox(height: 24),
                Text(
                  'Kho được truy cập',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (user.warehouses.isEmpty)
                  const Text('Tài khoản chưa được cấp quyền kho.'),
                for (final warehouse in user.warehouses)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.warehouse_outlined),
                      title: Text(warehouse.name),
                      subtitle: Text(warehouse.code),
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: auth.busy
                      ? null
                      : () => setState(
                          () => _changingPassword = !_changingPassword,
                        ),
                  icon: const Icon(Icons.lock_reset),
                  label: Text(
                    _changingPassword ? 'Đóng đổi mật khẩu' : 'Đổi mật khẩu',
                  ),
                ),
                if (_changingPassword) _ChangePasswordForm(auth: auth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm({required this.auth});
  final AuthController auth;
  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              enabled: !widget.auth.busy,
              maxLength: 128,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu hiện tại',
                counterText: '',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Nhập mật khẩu hiện tại.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              enabled: !widget.auth.busy,
              maxLength: 128,
              decoration: const InputDecoration(
                labelText: 'Mật khẩu mới (12–128 ký tự)',
                counterText: '',
              ),
              validator: (v) => v == null || v.trim().isEmpty || v.length < 12
                  ? 'Mật khẩu cần từ 12 đến 128 ký tự.'
                  : v == _current.text
                  ? 'Mật khẩu mới phải khác mật khẩu hiện tại.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              enabled: !widget.auth.busy,
              maxLength: 128,
              decoration: const InputDecoration(
                labelText: 'Xác nhận mật khẩu mới',
                counterText: '',
              ),
              validator: (v) =>
                  v != _next.text ? 'Mật khẩu xác nhận chưa khớp.' : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: widget.auth.busy
                  ? null
                  : () {
                      if (_form.currentState!.validate()) {
                        widget.auth.changePassword(_current.text, _next.text);
                      }
                    },
              child: const Text('Lưu và đăng nhập lại'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.message, {this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Text(
      message,
      style: TextStyle(
        color: error ? Theme.of(context).colorScheme.error : null,
      ),
    ),
  );
}
