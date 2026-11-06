import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/state/auth_controller.dart';
import 'data/warehouse_repository.dart';
import 'state/warehouse_controller.dart';
import 'warehouse_dialogs.dart';

class ServerWarehousesPage extends StatefulWidget {
  const ServerWarehousesPage({
    super.key,
    required this.controller,
    required this.auth,
    required this.canManage,
  });
  final WarehouseController controller;
  final AuthController auth;
  final bool canManage;
  @override
  State<ServerWarehousesPage> createState() => _ServerWarehousesPageState();
}

class _ServerWarehousesPageState extends State<ServerWarehousesPage> {
  late final _search = TextEditingController(text: widget.controller.search);
  Timer? _debounce;
  bool _opening = false;
  WarehouseRepository get _repository => widget.controller.repository;
  bool get _active => mounted && widget.auth.status == SessionStatus.signedIn;
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchNow(String value) {
    _debounce?.cancel();
    widget.controller.load(page: 1, search: value);
  }

  void _message(String text) {
    if (_active) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _open({
    ServerWarehouse? item,
    bool delete = false,
    bool viewOnly = false,
  }) async {
    if (_opening) return;
    if (!viewOnly && !widget.canManage) return;
    setState(() => _opening = true);
    try {
      final detail = item == null ? null : await _repository.get(item.id);
      if (!mounted || !_active) return;
      setState(() => _opening = false);
      if (viewOnly) {
        await showDialog<void>(
          context: context,
          useRootNavigator: false,
          builder: (context) => AlertDialog(
            title: const Text('Thông tin kho'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mã: ${detail!.code}'),
                  const SizedBox(height: 12),
                  Text('Tên: ${detail.name}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
        return;
      }
      final result = await showDialog<WarehouseDialogResult>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => delete
            ? WarehouseDeleteDialog(repository: _repository, initial: detail!)
            : WarehouseEditorDialog(repository: _repository, initial: detail),
      );
      if (!_active) return;
      if (result != null) {
        await widget.controller.load(page: item == null ? 1 : null);
        if (_active) await widget.auth.refreshUser();
        if (result == WarehouseDialogResult.saved) {
          _message(
            delete
                ? 'Đã xóa kho.'
                : item == null
                ? 'Đã thêm kho.'
                : 'Đã cập nhật kho.',
          );
        }
      }
    } on ApiException catch (e) {
      _message(warehouseError(e));
      if (_active && e.statusCode == 404) await widget.controller.load();
    } catch (_) {
      _message('Không thể mở thông tin kho. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _actions(ServerWarehouse item) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: ValueKey('warehouses.view.${item.id}'),
        tooltip: 'Xem chi tiết',
        onPressed: _opening ? null : () => _open(item: item, viewOnly: true),
        icon: const Icon(Icons.info_outline),
      ),
      if (widget.canManage) ...[
        IconButton(
          key: ValueKey('warehouses.edit.${item.id}'),
          tooltip: 'Sửa kho',
          onPressed: _opening ? null : () => _open(item: item),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: ValueKey('warehouses.delete.${item.id}'),
          tooltip: 'Xóa kho',
          onPressed: _opening ? null : () => _open(item: item, delete: true),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      return LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 16 : 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Danh mục kho',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.canManage
                              ? 'Quản lý thông tin kho.'
                              : 'Các kho bạn được cấp quyền truy cập.',
                        ),
                      ],
                    ),
                    if (widget.canManage)
                      FilledButton.icon(
                        key: const ValueKey('warehouses.add'),
                        onPressed: _opening ? null : () => _open(),
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm kho'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: compact ? constraints.maxWidth - 32 : 330,
                      child: TextField(
                        key: const ValueKey('warehouses.search'),
                        controller: _search,
                        maxLength: 200,
                        onChanged: (value) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 350),
                            () => _searchNow(value),
                          );
                        },
                        onSubmitted: _searchNow,
                        decoration: const InputDecoration(
                          labelText: 'Tìm mã hoặc tên kho',
                          counterText: '',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: const ValueKey('warehouses.sort'),
                        initialValue: c.sort,
                        decoration: const InputDecoration(labelText: 'Sắp xếp'),
                        items: const [
                          DropdownMenuItem(
                            value: 'code',
                            child: Text('Mã kho'),
                          ),
                          DropdownMenuItem(
                            value: 'name',
                            child: Text('Tên kho'),
                          ),
                        ],
                        onChanged: c.loading
                            ? null
                            : (value) {
                                if (value != null) c.load(page: 1, sort: value);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: const ValueKey('warehouses.pageSize'),
                        initialValue: c.pageSize,
                        decoration: const InputDecoration(labelText: 'Số dòng'),
                        items: [
                          for (final size in [10, 20, 50])
                            DropdownMenuItem(value: size, child: Text('$size')),
                        ],
                        onChanged: c.loading
                            ? null
                            : (value) {
                                if (value != null) {
                                  c.load(page: 1, pageSize: value);
                                }
                              },
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('warehouses.reload'),
                      tooltip: 'Tải lại danh sách',
                      onPressed: c.loading
                          ? null
                          : () => _searchNow(_search.text),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (c.loading || _opening) const LinearProgressIndicator(),
                if (c.error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            c.error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          TextButton(
                            onPressed: c.loading ? null : () => c.load(),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!c.loading && c.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Không có kho phù hợp.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (c.items.isNotEmpty)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: compact
                        ? Column(
                            children: [
                              for (final item in c.items)
                                Column(
                                  children: [
                                    ListTile(
                                      title: Text(item.name),
                                      subtitle: Text(item.code),
                                      onTap: _opening
                                          ? null
                                          : () => _open(
                                              item: item,
                                              viewOnly: true,
                                            ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: _actions(item),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                ),
                            ],
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Mã kho')),
                                DataColumn(label: Text('Tên kho')),
                                DataColumn(label: Text('Thao tác')),
                              ],
                              rows: [
                                for (final item in c.items)
                                  DataRow(
                                    cells: [
                                      DataCell(Text(item.code)),
                                      DataCell(Text(item.name)),
                                      DataCell(_actions(item)),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${c.totalItems} kho · Trang ${c.totalPages == 0 ? 0 : c.page}/${c.totalPages}',
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('warehouses.previous'),
                          tooltip: 'Trang trước',
                          onPressed: c.loading || c.page <= 1
                              ? null
                              : () => c.load(page: c.page - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          key: const ValueKey('warehouses.next'),
                          tooltip: 'Trang sau',
                          onPressed: c.loading || c.page >= c.totalPages
                              ? null
                              : () => c.load(page: c.page + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
