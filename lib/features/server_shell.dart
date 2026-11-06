import 'package:flutter/material.dart';

import 'auth/models/session_user.dart';
import 'auth/server_auth_page.dart';
import 'auth/state/auth_controller.dart';
import 'catalog/data/catalog_repository.dart';
import 'catalog/state/catalog_controller.dart';
import 'catalog/server_catalog_page.dart';
import 'batches/batch_controller.dart';
import 'batches/batch_repository.dart';
import 'batches/server_batches_page.dart';
import 'warehouses/data/warehouse_repository.dart';
import 'warehouses/state/warehouse_controller.dart';
import 'warehouses/server_warehouses_page.dart';

String sessionRoleLabel(SessionUser user) => switch (user.role) {
  'Admin' => 'Quản trị viên',
  'QualityManager' => 'Quản lý chất lượng',
  _ => 'Nhân viên kho',
};

// Dialogs belong to this session's nested Navigator. A revoked/logout session
// removes the whole Navigator, including any open editor/confirmation route.
class ServerShell extends StatelessWidget {
  const ServerShell({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => Navigator(
    onGenerateRoute: (_) =>
        MaterialPageRoute<void>(builder: (_) => _ShellFrame(auth: auth)),
  );
}

class _ShellFrame extends StatefulWidget {
  const _ShellFrame({required this.auth});
  final AuthController auth;
  @override
  State<_ShellFrame> createState() => _ShellFrameState();
}

class _ShellFrameState extends State<_ShellFrame> {
  int _selected = 0;
  late final _batches = BatchController(
    BatchRepository(widget.auth.repository.api),
  );
  late final WarehouseController _warehouses = WarehouseController(
    WarehouseRepository(widget.auth.repository.api),
  );
  late final _organizations = CatalogController(
    CatalogRepository(
      widget.auth.repository.api,
      CatalogResource.organizations,
    ),
  );
  late final _vaccines = CatalogController(
    CatalogRepository(widget.auth.repository.api, CatalogResource.vaccines),
  );
  @override
  void dispose() {
    _warehouses.dispose();
    _organizations.dispose();
    _vaccines.dispose();
    _batches.dispose();
    super.dispose();
  }

  void _select(int value, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.of(context).pop();
    setState(() => _selected = value);
  }

  Widget _navigation(bool drawer, SessionUser user) => SafeArea(
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                leading: Icon(Icons.vaccines_outlined),
                title: Text('VaxStock'),
                subtitle: Text('Quản lý kho vaccine'),
              ),
              const Divider(),
              ListTile(
                key: const ValueKey('server.nav.account'),
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Tài khoản'),
                selected: _selected == 0,
                onTap: () => _select(0, closeDrawer: drawer),
              ),
              ListTile(
                key: const ValueKey('server.nav.warehouses'),
                leading: const Icon(Icons.warehouse_outlined),
                title: const Text('Kho'),
                selected: _selected == 1,
                onTap: () => _select(1, closeDrawer: drawer),
              ),
              ListTile(
                key: const ValueKey('server.nav.organizations'),
                leading: const Icon(Icons.business_outlined),
                title: const Text('Đối tác'),
                selected: _selected == 2,
                onTap: () => _select(2, closeDrawer: drawer),
              ),
              ListTile(
                key: const ValueKey('server.nav.vaccines'),
                leading: const Icon(Icons.vaccines_outlined),
                title: const Text('Vaccine'),
                selected: _selected == 3,
                onTap: () => _select(3, closeDrawer: drawer),
              ),
              ListTile(
                key: const ValueKey('server.nav.batches'),
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Lô vaccine'),
                selected: _selected == 4,
                onTap: () => _select(4, closeDrawer: drawer),
              ),
            ],
          ),
        ),
        const Divider(),
        ListTile(
          title: Text(
            user.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(sessionRoleLabel(user)),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.auth,
    builder: (context, _) {
      final auth = widget.auth;
      final user = auth.user;
      if (user == null) return const SizedBox.shrink();
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final body = switch (_selected) {
        0 => SessionAccountPage(auth: auth, embedded: true),
        1 => ServerWarehousesPage(
          controller: _warehouses,
          auth: auth,
          canManage: user.role == 'Admin',
        ),
        4 => ServerBatchesPage(
          controller: _batches,
          auth: auth,
          canManage: user.role == 'Admin',
        ),
        _ => ServerCatalogPage(
          key: ValueKey('catalog.$_selected'),
          controller: _selected == 2 ? _organizations : _vaccines,
          auth: auth,
          canManage: user.role == 'Admin',
        ),
      };
      return Scaffold(
        appBar: AppBar(
          title: Text(
            ['Tài khoản', 'Kho', 'Đối tác', 'Vaccine', 'Lô vaccine'][_selected],
          ),
          actions: [
            IconButton(
              tooltip: 'Cập nhật thông tin',
              onPressed: auth.busy
                  ? null
                  : () async {
                      await auth.refreshUser();
                      if (mounted &&
                          _selected == 1 &&
                          auth.status == SessionStatus.signedIn) {
                        await _warehouses.load();
                      }
                      if (mounted &&
                          (_selected == 2 || _selected == 3) &&
                          auth.status == SessionStatus.signedIn) {
                        await (_selected == 2 ? _organizations : _vaccines)
                            .load();
                      }
                      if (mounted &&
                          _selected == 4 &&
                          auth.status == SessionStatus.signedIn) {
                        await _batches.load();
                      }
                    },
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              key: const ValueKey('server.logout'),
              tooltip: 'Đăng xuất mọi phiên',
              onPressed: auth.busy ? null : auth.logout,
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: wide ? null : Drawer(child: _navigation(true, user)),
        body: wide
            ? Row(
                children: [
                  SizedBox(
                    width: 242,
                    child: Material(
                      color: Colors.white,
                      child: _navigation(false, user),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
      );
    },
  );
}
