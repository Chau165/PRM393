import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/domain_exception.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/first_or_null.dart';
import '../../shared/widgets/common.dart';

enum MasterDataKind { warehouse, unit, category, product, supplier }

class MasterDataPage extends StatefulWidget {
  const MasterDataPage({
    super.key,
    required this.state,
    required this.user,
    required this.kind,
  });

  final WarehouseAppState state;
  final AppUser user;
  final MasterDataKind kind;

  @override
  State<MasterDataPage> createState() => _MasterDataPageState();
}

class _MasterDataPageState extends State<MasterDataPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    MasterDataKind.warehouse => 'Danh mục Kho',
    MasterDataKind.unit => 'Danh mục Đơn vị tính',
    MasterDataKind.category => 'Danh mục Loại sản phẩm',
    MasterDataKind.product => 'Danh mục Sản phẩm',
    MasterDataKind.supplier => 'Danh mục Nhà cung cấp',
  };

  List<String> get _headers => switch (widget.kind) {
    MasterDataKind.warehouse => ['Tên kho', 'Ghi chú'],
    MasterDataKind.unit => ['Tên đơn vị tính', 'Ghi chú'],
    MasterDataKind.category => ['Mã loại', 'Tên loại', 'Ghi chú'],
    MasterDataKind.product => [
      'Mã sản phẩm',
      'Tên sản phẩm',
      'Loại',
      'Đơn vị tính',
    ],
    MasterDataKind.supplier => [
      'Mã nhà cung cấp',
      'Tên nhà cung cấp',
      'Ghi chú',
    ],
  };

  List<_MasterRow> get _rows {
    final rows = switch (widget.kind) {
      MasterDataKind.warehouse =>
        widget.state.data.warehouses
            .map((item) => _MasterRow(item.id, [item.name, item.note], item))
            .toList(),
      MasterDataKind.unit =>
        widget.state.data.units
            .map((item) => _MasterRow(item.id, [item.name, item.note], item))
            .toList(),
      MasterDataKind.category =>
        widget.state.data.categories
            .map(
              (item) =>
                  _MasterRow(item.id, [item.code, item.name, item.note], item),
            )
            .toList(),
      MasterDataKind.product => widget.state.data.products.map((item) {
        final category = firstOrNull(
          widget.state.data.categories.where(
            (value) => value.id == item.categoryId,
          ),
        );
        final unit = firstOrNull(
          widget.state.data.units.where((value) => value.id == item.unitId),
        );
        return _MasterRow(item.id, [
          item.code,
          item.name,
          category?.name ?? '',
          unit?.name ?? '',
        ], item);
      }).toList(),
      MasterDataKind.supplier =>
        widget.state.data.suppliers
            .map(
              (item) =>
                  _MasterRow(item.id, [item.code, item.name, item.note], item),
            )
            .toList(),
    };
    if (_query.trim().isEmpty) return rows;
    final query = _query.trim().toLowerCase();
    return rows
        .where((row) => row.cells.join(' ').toLowerCase().contains(query))
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
                title: _title,
                subtitle: 'Tìm kiếm và quản lý dữ liệu danh mục.',
                action: FilledButton.icon(
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm mới'),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Tìm trong $_title...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa tìm kiếm',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                clipBehavior: Clip.antiAlias,
                child: rows.isEmpty
                    ? const SizedBox(
                        height: 240,
                        child: EmptyState(title: 'Không có dữ liệu phù hợp'),
                      )
                    : compact
                    ? Column(
                        children: [for (final row in rows) _mobileRow(row)],
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            for (final header in _headers)
                              DataColumn(label: Text(header)),
                            const DataColumn(label: Text('Thao tác')),
                          ],
                          rows: [
                            for (final row in rows)
                              DataRow(
                                cells: [
                                  for (final cell in row.cells)
                                    DataCell(Text(cell.isEmpty ? '—' : cell)),
                                  DataCell(_rowActions(row)),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                '${rows.length} mục',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _mobileRow(_MasterRow row) {
    final primary = row.cells.length > 1 && row.cells[1].isNotEmpty
        ? row.cells[1]
        : row.cells.first;
    final secondary = row.cells.first == primary
        ? row.cells.skip(1).join(' · ')
        : row.cells.first;
    return Column(
      children: [
        ListTile(
          title: Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            secondary.isEmpty ? '—' : secondary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _rowActions(row),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _rowActions(_MasterRow row) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Sửa',
          onPressed: () => _edit(row),
          icon: const Icon(Icons.edit_outlined, size: 19),
        ),
        IconButton(
          tooltip: 'Xóa',
          onPressed: () => _confirmDelete(row),
          icon: const Icon(Icons.delete_outline, size: 19),
        ),
      ],
    );
  }

  Future<void> _edit([_MasterRow? row]) async {
    final item = row?.value;
    final fields = _fieldSpecs(item);
    final values = {for (final field in fields) field.key: field.initialValue};
    final formKey = GlobalKey<FormState>();
    var categoryId = item is Product
        ? item.categoryId
        : firstOrNull(widget.state.data.categories)?.id;
    var unitId = item is Product
        ? item.unitId
        : firstOrNull(widget.state.data.units)?.id;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            row == null
                ? 'Thêm ${_singularTitle()}'
                : 'Sửa ${_singularTitle()}',
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final field in fields) ...[
                      TextFormField(
                        initialValue: field.initialValue,
                        decoration: InputDecoration(labelText: field.label),
                        maxLines: field.key == 'note' ? 2 : 1,
                        onSaved: (value) => values[field.key] = value ?? '',
                        validator: field.required
                            ? (value) => (value == null || value.trim().isEmpty)
                                  ? '${field.label} không được để trống.'
                                  : null
                            : null,
                      ),
                      const SizedBox(height: 13),
                    ],
                    if (widget.kind == MasterDataKind.product) ...[
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Loại sản phẩm',
                        ),
                        items: [
                          for (final category in widget.state.data.categories)
                            DropdownMenuItem(
                              value: category.id,
                              child: Text(
                                '${category.code} · ${category.name}',
                              ),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => categoryId = value),
                        validator: (value) => value == null
                            ? 'Vui lòng chọn loại sản phẩm.'
                            : null,
                      ),
                      const SizedBox(height: 13),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: unitId,
                        decoration: const InputDecoration(
                          labelText: 'Đơn vị tính',
                        ),
                        items: [
                          for (final unit in widget.state.data.units)
                            DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => unitId = value),
                        validator: (value) =>
                            value == null ? 'Vui lòng chọn đơn vị tính.' : null,
                      ),
                    ],
                  ],
                ),
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
                formKey.currentState?.save();
                try {
                  await _saveMaster(row, values, categoryId, unitId);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) {
                    showAppMessage(
                      this.context,
                      row == null ? 'Đã thêm dữ liệu.' : 'Đã cập nhật dữ liệu.',
                    );
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

  List<_FieldSpec> _fieldSpecs(Object? item) => switch (widget.kind) {
    MasterDataKind.warehouse => [
      _FieldSpec(
        'name',
        'Tên kho',
        item is Warehouse ? item.name : '',
        required: true,
      ),
      _FieldSpec('note', 'Ghi chú', item is Warehouse ? item.note : ''),
    ],
    MasterDataKind.unit => [
      _FieldSpec(
        'name',
        'Tên đơn vị tính',
        item is UnitOfMeasure ? item.name : '',
        required: true,
      ),
      _FieldSpec('note', 'Ghi chú', item is UnitOfMeasure ? item.note : ''),
    ],
    MasterDataKind.category => [
      _FieldSpec(
        'code',
        'Mã loại',
        item is ProductCategory ? item.code : '',
        required: true,
      ),
      _FieldSpec(
        'name',
        'Tên loại sản phẩm',
        item is ProductCategory ? item.name : '',
        required: true,
      ),
      _FieldSpec('note', 'Ghi chú', item is ProductCategory ? item.note : ''),
    ],
    MasterDataKind.product => [
      _FieldSpec(
        'code',
        'Mã sản phẩm',
        item is Product ? item.code : '',
        required: true,
      ),
      _FieldSpec(
        'name',
        'Tên sản phẩm',
        item is Product ? item.name : '',
        required: true,
      ),
      _FieldSpec('note', 'Ghi chú', item is Product ? item.note : ''),
    ],
    MasterDataKind.supplier => [
      _FieldSpec(
        'code',
        'Mã nhà cung cấp',
        item is Supplier ? item.code : '',
        required: true,
      ),
      _FieldSpec(
        'name',
        'Tên nhà cung cấp',
        item is Supplier ? item.name : '',
        required: true,
      ),
      _FieldSpec('note', 'Ghi chú', item is Supplier ? item.note : ''),
    ],
  };

  Future<void> _saveMaster(
    _MasterRow? row,
    Map<String, String> values,
    int? categoryId,
    int? unitId,
  ) async {
    final id = row?.id;
    String value(String key) => values[key]?.trim() ?? '';
    switch (widget.kind) {
      case MasterDataKind.warehouse:
        if (id == null) {
          await widget.state.createWarehouse(
            widget.user,
            name: value('name'),
            note: value('note'),
          );
        } else {
          await widget.state.updateWarehouse(
            widget.user,
            id: id,
            name: value('name'),
            note: value('note'),
          );
        }
        break;
      case MasterDataKind.unit:
        if (id == null) {
          await widget.state.createUnit(
            widget.user,
            name: value('name'),
            note: value('note'),
          );
        } else {
          await widget.state.updateUnit(
            widget.user,
            id: id,
            name: value('name'),
            note: value('note'),
          );
        }
        break;
      case MasterDataKind.category:
        if (id == null) {
          await widget.state.createCategory(
            widget.user,
            code: value('code'),
            name: value('name'),
            note: value('note'),
          );
        } else {
          await widget.state.updateCategory(
            widget.user,
            id: id,
            code: value('code'),
            name: value('name'),
            note: value('note'),
          );
        }
        break;
      case MasterDataKind.product:
        if (categoryId == null || unitId == null) return;
        if (id == null) {
          await widget.state.createProduct(
            widget.user,
            code: value('code'),
            name: value('name'),
            categoryId: categoryId,
            unitId: unitId,
            note: value('note'),
          );
        } else {
          await widget.state.updateProduct(
            widget.user,
            id: id,
            code: value('code'),
            name: value('name'),
            categoryId: categoryId,
            unitId: unitId,
            note: value('note'),
          );
        }
        break;
      case MasterDataKind.supplier:
        if (id == null) {
          await widget.state.createSupplier(
            widget.user,
            code: value('code'),
            name: value('name'),
            note: value('note'),
          );
        } else {
          await widget.state.updateSupplier(
            widget.user,
            id: id,
            code: value('code'),
            name: value('name'),
            note: value('note'),
          );
        }
        break;
    }
  }

  Future<void> _confirmDelete(_MasterRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa dữ liệu?'),
        content: Text('Bạn có chắc muốn xóa “${row.cells.first}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      switch (widget.kind) {
        case MasterDataKind.warehouse:
          await widget.state.deleteWarehouse(widget.user, row.id);
          break;
        case MasterDataKind.unit:
          await widget.state.deleteUnit(widget.user, row.id);
          break;
        case MasterDataKind.category:
          await widget.state.deleteCategory(widget.user, row.id);
          break;
        case MasterDataKind.product:
          await widget.state.deleteProduct(widget.user, row.id);
          break;
        case MasterDataKind.supplier:
          await widget.state.deleteSupplier(widget.user, row.id);
          break;
      }
      if (mounted) showAppMessage(context, 'Đã xóa dữ liệu.');
    } catch (error) {
      if (mounted) showAppMessage(context, _message(error), isError: true);
    }
  }

  String _singularTitle() => switch (widget.kind) {
    MasterDataKind.warehouse => 'kho',
    MasterDataKind.unit => 'đơn vị tính',
    MasterDataKind.category => 'loại sản phẩm',
    MasterDataKind.product => 'sản phẩm',
    MasterDataKind.supplier => 'nhà cung cấp',
  };

  String _message(Object error) => error is DomainException
      ? error.message
      : 'Không thể lưu dữ liệu. Vui lòng thử lại.';
}

class _MasterRow {
  const _MasterRow(this.id, this.cells, this.value);

  final int id;
  final List<String> cells;
  final Object value;
}

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label,
    this.initialValue, {
    this.required = false,
  });

  final String key;
  final String label;
  final String initialValue;
  final bool required;
}
