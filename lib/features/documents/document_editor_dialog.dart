import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/first_or_null.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';

class DocumentLineDraft {
  const DocumentLineDraft({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
  });

  final int id;
  final int productId;
  final double quantity;
  final double unitPrice;
}

class DocumentDraftResult {
  const DocumentDraftResult({
    required this.documentNo,
    required this.warehouseId,
    required this.supplierId,
    required this.documentDate,
    required this.note,
    required this.details,
    required this.postAfterSave,
  });

  final String documentNo;
  final int warehouseId;
  final int? supplierId;
  final DateTime documentDate;
  final String note;
  final List<DocumentLineDraft> details;
  final bool postAfterSave;
}

class DocumentEditorDialog extends StatefulWidget {
  const DocumentEditorDialog({
    super.key,
    required this.state,
    required this.user,
    required this.isReceipt,
    this.receipt,
    this.issue,
  });

  final WarehouseAppState state;
  final AppUser user;
  final bool isReceipt;
  final ReceiptDocument? receipt;
  final IssueDocument? issue;

  @override
  State<DocumentEditorDialog> createState() => _DocumentEditorDialogState();
}

class _DocumentEditorDialogState extends State<DocumentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _documentNo;
  late final TextEditingController _note;
  late int? _warehouseId;
  late int? _supplierId;
  late DateTime _documentDate;
  late List<DocumentLineDraft> _details;

  bool get _readOnly =>
      widget.receipt?.status == DocumentStatus.posted ||
      widget.issue?.status == DocumentStatus.posted;

  int? get _id => widget.receipt?.id ?? widget.issue?.id;

  @override
  void initState() {
    super.initState();
    final receipt = widget.receipt;
    final issue = widget.issue;
    _documentNo = TextEditingController(
      text: receipt?.documentNo ?? issue?.documentNo ?? '',
    );
    _note = TextEditingController(text: receipt?.note ?? issue?.note ?? '');
    final allowed = widget.state.getAllowedWarehouses(widget.user);
    _warehouseId =
        receipt?.warehouseId ?? issue?.warehouseId ?? _firstId(allowed);
    _supplierId =
        receipt?.supplierId ?? firstOrNull(widget.state.data.suppliers)?.id;
    _documentDate =
        receipt?.documentDate ?? issue?.documentDate ?? DateTime.now();
    _details = receipt != null
        ? widget.state
              .receiptDetailsFor(widget.user, receipt.id)
              .map(
                (line) => DocumentLineDraft(
                  id: line.id,
                  productId: line.productId,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                ),
              )
              .toList()
        : issue != null
        ? widget.state
              .issueDetailsFor(widget.user, issue.id)
              .map(
                (line) => DocumentLineDraft(
                  id: line.id,
                  productId: line.productId,
                  quantity: line.quantity,
                  unitPrice: line.unitPrice,
                ),
              )
              .toList()
        : [];
  }

  @override
  void dispose() {
    _documentNo.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receipt = widget.isReceipt;
    final warehouses = widget.state.getAllowedWarehouses(widget.user);
    final maxHeight = MediaQuery.sizeOf(context).height * .86;
    final totalQuantity = _details.fold<double>(
      0,
      (sum, line) => sum + line.quantity,
    );
    final totalAmount = _details.fold<double>(
      0,
      (sum, line) => sum + line.quantity * line.unitPrice,
    );

    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Row(
        children: [
          Expanded(child: Text(receipt ? 'Phiếu nhập kho' : 'Phiếu xuất kho')),
          if (_id != null) StatusBadge(posted: _readOnly),
        ],
      ),
      content: SizedBox(
        width: 820,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 540;
                      final fields = <Widget>[
                        TextFormField(
                          controller: _documentNo,
                          readOnly: _readOnly,
                          decoration: const InputDecoration(
                            labelText: 'Số phiếu',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Số phiếu không được để trống.'
                              : null,
                        ),
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: _warehouseId,
                          decoration: const InputDecoration(labelText: 'Kho'),
                          items: [
                            for (final warehouse in warehouses)
                              DropdownMenuItem(
                                value: warehouse.id,
                                child: Text(warehouse.name),
                              ),
                          ],
                          onChanged: _readOnly
                              ? null
                              : (value) => setState(() => _warehouseId = value),
                          validator: (value) =>
                              value == null ? 'Vui lòng chọn kho.' : null,
                        ),
                      ];
                      if (receipt) {
                        fields.add(
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _supplierId,
                            decoration: const InputDecoration(
                              labelText: 'Nhà cung cấp',
                            ),
                            items: [
                              for (final supplier
                                  in widget.state.data.suppliers)
                                DropdownMenuItem(
                                  value: supplier.id,
                                  child: Text(supplier.name),
                                ),
                            ],
                            onChanged: _readOnly
                                ? null
                                : (value) =>
                                      setState(() => _supplierId = value),
                            validator: (value) => value == null
                                ? 'Vui lòng chọn nhà cung cấp.'
                                : null,
                          ),
                        );
                      }
                      fields.add(
                        OutlinedButton.icon(
                          onPressed: _readOnly ? null : _pickDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text('Ngày: ${formatDate(_documentDate)}'),
                        ),
                      );
                      fields.add(
                        TextFormField(
                          controller: _note,
                          readOnly: _readOnly,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Ghi chú',
                          ),
                        ),
                      );
                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final field in fields) ...[
                              field,
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      }
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final field in fields)
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: field,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Chi tiết phiếu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (!_readOnly)
                        OutlinedButton.icon(
                          onPressed: _editLine,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Thêm sản phẩm'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_details.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F8FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Chưa có sản phẩm trong phiếu.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth < 620
                          ? Column(
                              children: [
                                for (var i = 0; i < _details.length; i++)
                                  _mobileLine(i),
                              ],
                            )
                          : _desktopLines(),
                    ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Tổng số lượng: ${formatQuantity(totalQuantity)}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          'Tổng tiền: ${formatCurrency(totalAmount)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_readOnly ? 'Đóng' : 'Hủy'),
        ),
        if (!_readOnly) ...[
          OutlinedButton.icon(
            onPressed: () => _submit(post: false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Lưu nháp'),
          ),
          FilledButton.icon(
            onPressed: () => _submit(post: true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Post phiếu'),
          ),
        ],
      ],
    );
  }

  Widget _desktopLines() {
    return Card(
      elevation: 0,
      color: const Color(0xFFF9FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE7ECF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Sản phẩm')),
            DataColumn(label: Text('ĐVT')),
            DataColumn(label: Text('Số lượng'), numeric: true),
            DataColumn(label: Text('Đơn giá'), numeric: true),
            DataColumn(label: Text('Thành tiền'), numeric: true),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (var i = 0; i < _details.length; i++)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      _product(_details[i].productId)?.name ??
                          'Sản phẩm đã xóa',
                    ),
                  ),
                  DataCell(Text(_unit(_details[i].productId))),
                  DataCell(Text(formatQuantity(_details[i].quantity))),
                  DataCell(Text(formatCurrency(_details[i].unitPrice))),
                  DataCell(
                    Text(
                      formatCurrency(
                        _details[i].quantity * _details[i].unitPrice,
                      ),
                    ),
                  ),
                  DataCell(_lineActions(i)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileLine(int index) {
    final line = _details[index];
    final product = _product(line.productId);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: const Color(0xFFF9FAFC),
      child: ListTile(
        title: Text(product?.name ?? 'Sản phẩm đã xóa'),
        subtitle: Text(
          '${formatQuantity(line.quantity)} ${_unit(line.productId)} × ${formatCurrency(line.unitPrice)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatCurrency(line.quantity * line.unitPrice),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (!_readOnly) _lineActions(index),
          ],
        ),
      ),
    );
  }

  Widget _lineActions(int index) => Row(
    mainAxisSize: MainAxisSize.min,
    children: _readOnly
        ? const []
        : [
            IconButton(
              tooltip: 'Sửa chi tiết',
              onPressed: () => _editLine(index),
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Xóa chi tiết',
              onPressed: () => setState(() => _details.removeAt(index)),
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
  );

  Future<void> _editLine([int? index]) async {
    if (widget.state.data.products.isEmpty) {
      showAppMessage(
        context,
        'Cần tạo sản phẩm trước khi lập phiếu.',
        isError: true,
      );
      return;
    }
    final current = index == null ? null : _details[index];
    final result = await showDialog<DocumentLineDraft>(
      context: context,
      builder: (_) => _DocumentLineEditorDialog(
        products: widget.state.data.products,
        units: widget.state.data.units,
        initial: current,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (index == null) {
          _details.add(result);
        } else {
          _details[index] = result;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _documentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày chứng từ',
    );
    if (date != null && mounted) setState(() => _documentDate = date);
  }

  Future<void> _submit({required bool post}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_warehouseId == null || (widget.isReceipt && _supplierId == null)) {
      return;
    }
    if (post && _details.isEmpty) {
      showAppMessage(
        context,
        'Phiếu phải có ít nhất một chi tiết trước khi Post.',
        isError: true,
      );
      return;
    }
    if (post) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận Post phiếu'),
          content: const Text(
            'Phiếu sau khi Post sẽ không thể chỉnh sửa. Bạn có chắc chắn?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Post phiếu'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    Navigator.pop(
      context,
      DocumentDraftResult(
        documentNo: _documentNo.text.trim(),
        warehouseId: _warehouseId!,
        supplierId: _supplierId,
        documentDate: _documentDate,
        note: _note.text.trim(),
        details: List.unmodifiable(_details),
        postAfterSave: post,
      ),
    );
  }

  Product? _product(int id) {
    for (final product in widget.state.data.products) {
      if (product.id == id) return product;
    }
    return null;
  }

  String _unit(int productId) {
    final product = _product(productId);
    for (final unit in widget.state.data.units) {
      if (unit.id == product?.unitId) return unit.name;
    }
    return '—';
  }
}

class _DocumentLineEditorDialog extends StatefulWidget {
  const _DocumentLineEditorDialog({
    required this.products,
    required this.units,
    required this.initial,
  });

  final List<Product> products;
  final List<UnitOfMeasure> units;
  final DocumentLineDraft? initial;

  @override
  State<_DocumentLineEditorDialog> createState() =>
      _DocumentLineEditorDialogState();
}

class _DocumentLineEditorDialogState extends State<_DocumentLineEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  late final TextEditingController _unitPrice;
  late int _productId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _productId = initial?.productId ?? widget.products.first.id;
    _quantity = TextEditingController(
      text: initial?.quantity.toString() ?? '1',
    );
    _unitPrice = TextEditingController(
      text: initial?.unitPrice.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitPrice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Thêm sản phẩm' : 'Sửa chi tiết'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _productId,
              decoration: const InputDecoration(labelText: 'Sản phẩm'),
              items: [
                for (final product in widget.products)
                  DropdownMenuItem(
                    value: product.id,
                    child: Text('${product.code} · ${product.name}'),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _productId = value ?? _productId),
            ),
            const SizedBox(height: 13),
            TextFormField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Số lượng'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return parsed == null || !parsed.isFinite || parsed <= 0
                    ? 'Số lượng phải lớn hơn 0.'
                    : null;
              },
            ),
            const SizedBox(height: 13),
            TextFormField(
              controller: _unitPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Đơn giá'),
              validator: (value) {
                final parsed = double.tryParse(value ?? '');
                return parsed == null || !parsed.isFinite || parsed < 0
                    ? 'Đơn giá không được nhỏ hơn 0.'
                    : null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Đơn vị: ${_unitName(_productId)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _apply, child: const Text('Áp dụng')),
    ],
  );

  void _apply() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      DocumentLineDraft(
        id: widget.initial?.id ?? 0,
        productId: _productId,
        quantity: double.parse(_quantity.text),
        unitPrice: double.parse(_unitPrice.text),
      ),
    );
  }

  String _unitName(int productId) {
    final product = firstOrNull(
      widget.products.where((item) => item.id == productId),
    );
    return firstOrNull(widget.units.where((item) => item.id == product?.unitId))
            ?.name ??
        '—';
  }
}

int? _firstId<T>(List<T> values) {
  if (values.isEmpty) return null;
  return switch (values.first) {
    Warehouse warehouse => warehouse.id,
    _ => null,
  };
}
