import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/domain_exception.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/first_or_null.dart';
import '../../shared/widgets/common.dart';

class WarehousePermissionsPage extends StatefulWidget {
  const WarehousePermissionsPage({
    super.key,
    required this.state,
    required this.user,
  });

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<WarehousePermissionsPage> createState() =>
      _WarehousePermissionsPageState();
}

class _WarehousePermissionsPageState extends State<WarehousePermissionsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_AssignmentRow> get _rows {
    final rows = widget.state.data.assignments.map((assignment) {
      final user = firstOrNull(
        widget.state.data.users.where((item) => item.id == assignment.userId),
      );
      final warehouse = firstOrNull(
        widget.state.data.warehouses.where(
          (item) => item.id == assignment.warehouseId,
        ),
      );
      return _AssignmentRow(
        assignment,
        user?.fullName ?? 'Người dùng không tồn tại',
        user?.username ?? '',
        warehouse?.name ?? 'Kho không tồn tại',
      );
    }).toList();
    final query = _query.trim().toLowerCase();
    return query.isEmpty
        ? rows
        : rows
              .where(
                (row) => '${row.fullName} ${row.username} ${row.warehouseName}'
                    .toLowerCase()
                    .contains(query),
              )
              .toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final rows = _rows;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Phân quyền Kho - User',
                subtitle: 'Mỗi người dùng chỉ xem và thao tác trong các kho được gán.',
                action: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm phân quyền'),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Tìm người dùng hoặc kho...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                child: rows.isEmpty
                    ? const SizedBox(
                        height: 220,
                        child: EmptyState(title: 'Chưa có phân quyền phù hợp'),
                      )
                    : compact
                    ? Column(
                        children: [for (final row in rows) _mobileRow(row)],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Người dùng')),
                            DataColumn(label: Text('Tên đăng nhập')),
                            DataColumn(label: Text('Kho được phép')),
                            DataColumn(label: Text('Thao tác')),
                          ],
                          rows: [
                            for (final row in rows)
                              DataRow(
                                cells: [
                                  DataCell(Text(row.fullName)),
                                  DataCell(Text(row.username)),
                                  DataCell(Text(row.warehouseName)),
                                  DataCell(_actions(row.assignment)),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileRow(_AssignmentRow row) => Column(
    children: [
      ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(row.fullName),
        subtitle: Text('${row.username} · ${row.warehouseName}'),
        trailing: _actions(row.assignment),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );

  Widget _actions(WarehouseUserAssignment assignment) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Sửa',
        onPressed: () => _edit(assignment),
        icon: const Icon(Icons.edit_outlined, size: 19),
      ),
      IconButton(
        tooltip: 'Xóa',
        onPressed: () => _delete(assignment),
        icon: const Icon(Icons.delete_outline, size: 19),
      ),
    ],
  );

  Future<void> _edit([WarehouseUserAssignment? assignment]) async {
    if (widget.state.data.users.isEmpty ||
        widget.state.data.warehouses.isEmpty) {
      showAppMessage(
        context,
        'Cần có người dùng và kho trước khi phân quyền.',
        isError: true,
      );
      return;
    }
    var selectedUserId = assignment?.userId ?? widget.state.data.users.first.id;
    var selectedWarehouseId =
        assignment?.warehouseId ?? widget.state.data.warehouses.first.id;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            assignment == null ? 'Thêm phân quyền kho' : 'Sửa phân quyền kho',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedUserId,
                    decoration: const InputDecoration(labelText: 'Người dùng'),
                    items: [
                      for (final user in widget.state.data.users)
                        DropdownMenuItem(
                          value: user.id,
                          child: Text('${user.fullName} (${user.username})'),
                        ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => selectedUserId = value ?? selectedUserId,
                    ),
                    validator: (value) =>
                        value == null ? 'Vui lòng chọn người dùng.' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selectedWarehouseId,
                    decoration: const InputDecoration(labelText: 'Kho'),
                    items: [
                      for (final warehouse in widget.state.data.warehouses)
                        DropdownMenuItem(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => selectedWarehouseId = value ?? selectedWarehouseId,
                    ),
                    validator: (value) =>
                        value == null ? 'Vui lòng chọn kho.' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                try {
                  if (assignment == null) {
                    await widget.state.createWarehouseAssignment(
                      widget.user,
                      userId: selectedUserId,
                      warehouseId: selectedWarehouseId,
                    );
                  } else {
                    await widget.state.updateWarehouseAssignment(
                      widget.user,
                      id: assignment.id,
                      userId: selectedUserId,
                      warehouseId: selectedWarehouseId,
                    );
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    showAppMessage(this.context, 'Đã lưu phân quyền.');
                  }
                } catch (error) {
                  if (dialogContext.mounted) {
                    showAppMessage(
                      dialogContext,
                      _message(error),
                      isError: true,
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(WarehouseUserAssignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gỡ phân quyền?'),
        content: const Text('Người dùng sẽ không còn truy cập kho này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ quyền'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.state.deleteWarehouseAssignment(widget.user, assignment.id);
      if (mounted) showAppMessage(context, 'Đã gỡ phân quyền.');
    } catch (error) {
      if (mounted) showAppMessage(context, _message(error), isError: true);
    }
  }

  String _message(Object error) =>
      error is DomainException ? error.message : 'Không thể lưu phân quyền.';
}

class _AssignmentRow {
  const _AssignmentRow(
    this.assignment,
    this.fullName,
    this.username,
    this.warehouseName,
  );

  final WarehouseUserAssignment assignment;
  final String fullName;
  final String username;
  final String warehouseName;
}
