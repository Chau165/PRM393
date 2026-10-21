import 'package:flutter/material.dart';

import '../../domain/services/warehouse_app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.state});

  final WarehouseAppState state;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _submitting = true);
    final success = await widget.state.login(_username.text, _password.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên đăng nhập hoặc mật khẩu không đúng.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 850;
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: _loginCard(context),
              ),
            ),
          );
          if (!wide) return form;
          return Row(
            children: [
              Expanded(flex: 6, child: _welcomePanel(context)),
              Expanded(flex: 5, child: form),
            ],
          );
        },
      ),
    );
  }

  Widget _welcomePanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(56),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, const Color(0xFF153E59)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 58),
          const SizedBox(height: 32),
          Text(
            'Kiểm soát kho\ntrong một nơi.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Theo dõi phiếu nhập, phiếu xuất và lượng hàng khả dụng theo từng kho.',
            style: TextStyle(
              color: Color(0xFFD9E8EF),
              fontSize: 17,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 34),
          const _WelcomePoint(
            icon: Icons.sync_alt,
            label: 'Sổ kho rõ ràng theo từng phiếu',
          ),
          const SizedBox(height: 14),
          const _WelcomePoint(
            icon: Icons.shield_outlined,
            label: 'Dữ liệu được giới hạn theo quyền kho',
          ),
          const SizedBox(height: 14),
          const _WelcomePoint(
            icon: Icons.devices_outlined,
            label: 'Dùng trên Android, Web và Windows',
          ),
        ],
      ),
    );
  }

  Widget _loginCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFE7ECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.inventory_2_rounded, color: colors.primary, size: 36),
            const SizedBox(height: 14),
            Text(
              'Warehouse Management Demo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text('Đăng nhập để tiếp tục', textAlign: TextAlign.center),
            const SizedBox(height: 26),
            TextField(
              key: const ValueKey('login.username'),
              controller: _username,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Tên đăng nhập',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('login.password'),
              controller: _password,
              obscureText: _obscurePassword,
              onSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              key: const ValueKey('login.submit'),
              onPressed: _submitting ? null : _login,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('Đăng nhập'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Tài khoản demo',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            const _DemoAccount(
              label: 'Quản trị',
              login: 'admin',
              password: 'admin123',
            ),
            const SizedBox(height: 7),
            const _DemoAccount(
              label: 'Nhân viên HCM',
              login: 'user_hcm',
              password: '123456',
            ),
            const SizedBox(height: 7),
            const _DemoAccount(
              label: 'Nhân viên Hà Nội',
              login: 'user_hn',
              password: '123456',
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAccount extends StatelessWidget {
  const _DemoAccount({
    required this.label,
    required this.login,
    required this.password,
  });

  final String label;
  final String login;
  final String password;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text(login, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 10),
        Text(password, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WelcomePoint extends StatelessWidget {
  const _WelcomePoint({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF99DDD1), size: 21),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
