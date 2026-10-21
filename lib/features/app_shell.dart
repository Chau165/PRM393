import 'package:flutter/material.dart';

import '../domain/models/warehouse_app_data.dart';
import '../domain/services/warehouse_app_state.dart';
import 'dashboard/dashboard_page.dart';
import 'documents/document_list_page.dart';
import 'inventory/inventory_page.dart';
import 'master_data/master_data_page.dart';
import 'reports/report_page.dart';
import 'warehouse_permissions/warehouse_permissions_page.dart';

enum _Destination {
  dashboard,
  warehouses,
  units,
  categories,
  products,
  suppliers,
  receipts,
  issues,
  inventory,
  reports,
  assignments,
}

class _NavigationEntry {
  const _NavigationEntry(this.destination, this.group, this.label, this.icon);

  final _Destination destination;
  final String group;
  final String label;
  final IconData icon;
}

class WarehouseShell extends StatefulWidget {
  const WarehouseShell({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<WarehouseShell> createState() => _WarehouseShellState();
}

class _WarehouseShellState extends State<WarehouseShell> {
  _Destination _selected = _Destination.dashboard;

  List<_NavigationEntry> get _entries {
    final entries = <_NavigationEntry>[
      const _NavigationEntry(
        _Destination.dashboard,
        'TỔNG QUAN',
        'Dashboard',
        Icons.space_dashboard_outlined,
      ),
      const _NavigationEntry(
        _Destination.warehouses,
        'DANH MỤC',
        'Kho',
        Icons.warehouse_outlined,
      ),
      const _NavigationEntry(
        _Destination.units,
        'DANH MỤC',
        'Đơn vị tính',
        Icons.straighten_outlined,
      ),
      const _NavigationEntry(
        _Destination.categories,
        'DANH MỤC',
        'Loại sản phẩm',
        Icons.category_outlined,
      ),
      const _NavigationEntry(
        _Destination.products,
        'DANH MỤC',
        'Sản phẩm',
        Icons.inventory_2_outlined,
      ),
      const _NavigationEntry(
        _Destination.suppliers,
        'DANH MỤC',
        'Nhà cung cấp',
        Icons.local_shipping_outlined,
      ),
      const _NavigationEntry(
        _Destination.receipts,
        'NGHIỆP VỤ',
        'Phiếu nhập',
        Icons.call_received_rounded,
      ),
      const _NavigationEntry(
        _Destination.issues,
        'NGHIỆP VỤ',
        'Phiếu xuất',
        Icons.call_made_rounded,
      ),
      const _NavigationEntry(
        _Destination.inventory,
        'NGHIỆP VỤ',
        'Tồn kho',
        Icons.stacked_bar_chart_rounded,
      ),
      const _NavigationEntry(
        _Destination.reports,
        'NGHIỆP VỤ',
        'Báo cáo XNT',
        Icons.assessment_outlined,
      ),
    ];
    if (widget.user.role == UserRole.admin) {
      entries.add(
        const _NavigationEntry(
          _Destination.assignments,
          'QUẢN TRỊ',
          'Phân quyền kho - user',
          Icons.admin_panel_settings_outlined,
        ),
      );
    }
    return entries;
  }

  String get _title =>
      _entries.firstWhere((entry) => entry.destination == _selected).label;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(width: 258, child: _desktopNavigation(context)),
                Expanded(
                  child: Column(
                    children: [
                      _desktopTopBar(context),
                      Expanded(child: _buildPage()),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(_title),
            actions: [
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: widget.state.logout,
                icon: const Icon(Icons.logout_rounded),
              ),
              const SizedBox(width: 6),
            ],
          ),
          drawer: Drawer(child: _navigationContent(context, isDrawer: true)),
          body: _buildPage(),
        );
      },
    );
  }

  Widget _desktopNavigation(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: _navigationContent(context),
    );
  }

  Widget _navigationContent(BuildContext context, {bool isDrawer = false}) {
    final colors = Theme.of(context).colorScheme;
    final navigationWidgets = <Widget>[];
    String? lastGroup;
    for (final entry in _entries) {
      if (entry.group != lastGroup) {
        navigationWidgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 8, 8),
            child: Text(
              entry.group,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8793A6),
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        lastGroup = entry.group;
      }
      navigationWidgets.add(
        _navigationTile(context, entry, isDrawer: isDrawer),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WAREHOUSE',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Management Demo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (isDrawer)
                  IconButton(
                    tooltip: 'Đóng menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              children: navigationWidgets,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    widget.user.fullName.isEmpty
                        ? 'U'
                        : widget.user.fullName[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      Text(
                        widget.user.role == UserRole.admin
                            ? 'Quản trị viên'
                            : 'Người dùng',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!isDrawer)
                  IconButton(
                    tooltip: 'Đăng xuất',
                    onPressed: widget.state.logout,
                    icon: const Icon(Icons.logout_rounded),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationTile(
    BuildContext context,
    _NavigationEntry entry, {
    required bool isDrawer,
  }) {
    final selected = _selected == entry.destination;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        selected: selected,
        selectedTileColor: colors.primaryContainer.withValues(alpha: .58),
        leading: Icon(
          entry.icon,
          size: 20,
          color: selected ? colors.primary : const Color(0xFF748198),
        ),
        title: Text(
          entry.label,
          style: TextStyle(
            color: selected ? colors.primary : const Color(0xFF3A4A63),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: () {
          setState(() => _selected = entry.destination);
          if (isDrawer) Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _desktopTopBar(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const Icon(Icons.account_circle_outlined, color: Color(0xFF718098)),
          const SizedBox(width: 9),
          Text(
            widget.user.fullName,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: widget.state.logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    final user = widget.user;
    return switch (_selected) {
      _Destination.dashboard => DashboardPage(state: widget.state, user: user),
      _Destination.warehouses => MasterDataPage(
        state: widget.state,
        user: user,
        kind: MasterDataKind.warehouse,
      ),
      _Destination.units => MasterDataPage(
        state: widget.state,
        user: user,
        kind: MasterDataKind.unit,
      ),
      _Destination.categories => MasterDataPage(
        state: widget.state,
        user: user,
        kind: MasterDataKind.category,
      ),
      _Destination.products => MasterDataPage(
        state: widget.state,
        user: user,
        kind: MasterDataKind.product,
      ),
      _Destination.suppliers => MasterDataPage(
        state: widget.state,
        user: user,
        kind: MasterDataKind.supplier,
      ),
      _Destination.receipts => DocumentListPage(
        state: widget.state,
        user: user,
        isReceipt: true,
      ),
      _Destination.issues => DocumentListPage(
        state: widget.state,
        user: user,
        isReceipt: false,
      ),
      _Destination.inventory => InventoryPage(state: widget.state, user: user),
      _Destination.reports => ReportPage(state: widget.state, user: user),
      _Destination.assignments => WarehousePermissionsPage(
        state: widget.state,
        user: user,
      ),
    };
  }
}
