import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/state/auth_controller.dart';
import 'batch_dialog.dart';
import 'batch_repository.dart';
import 'reference_picker.dart';

class BatchTracePage extends StatefulWidget {
  const BatchTracePage({
    super.key,
    required this.repository,
    required this.batchId,
    required this.auth,
  });
  final BatchRepository repository;
  final int batchId;
  final AuthController auth;
  @override
  State<BatchTracePage> createState() => _BatchTracePageState();
}

class _BatchTracePageState extends State<BatchTracePage> {
  BatchTrace? _data;
  int? _warehouseId;
  String _warehouseLabel = 'Tất cả kho được phép';
  int _page = 1, _size = 20, _generation = 0;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final generation = ++_generation, token = widget.repository.api.token;
    setState(() {
      _page = page ?? _page;
      _busy = true;
      _error = null;
      _data = null;
    });
    bool active() =>
        mounted &&
        generation == _generation &&
        token == widget.repository.api.token;
    try {
      final data = await widget.repository.trace(
        widget.batchId,
        warehouseId: _warehouseId,
        page: _page,
        pageSize: _size,
      );
      if (!active()) return;
      if (data.totalPages > 0 && _page > data.totalPages) {
        await _load(page: data.totalPages);
        return;
      }
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (active()) setState(() => _error = batchError(e));
    } catch (_) {
      if (active()) setState(() => _error = 'Không đọc được truy xuất lô.');
    } finally {
      if (active()) setState(() => _busy = false);
    }
  }

  Future<void> _pickWarehouse() async {
    // GET warehouses already applies assignments for W/Q and pages for Admin.
    final picked = await showDialog<BatchReference>(
      context: context,
      useRootNavigator: false,
      builder: (_) =>
          BatchReferencePicker(api: widget.repository.api, warehouses: true),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _warehouseId = picked.id;
      _warehouseLabel = picked.label;
    });
    await _load(page: 1);
  }

  String _source(String s) => switch (s) {
    'Receipt' => 'Nhập kho',
    'Issue' => 'Xuất kho',
    'StockDisposition' => 'Xử lý hàng',
    _ => s,
  };
  String _posted(String s) {
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    final vn = d.toUtc().add(const Duration(hours: 7));
    return '${vn.toIso8601String().substring(0, 19).replaceFirst('T', ' ')} (UTC+7)';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Truy xuất lô'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _busy ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('batch.trace.warehouse'),
                    onPressed: _pickWarehouse,
                    icon: const Icon(Icons.warehouse_outlined),
                    label: Text(_warehouseLabel),
                  ),
                  if (_warehouseId != null)
                    TextButton(
                      key: const ValueKey('batch.trace.clear'),
                      onPressed: () {
                        setState(() {
                          _warehouseId = null;
                          _warehouseLabel = 'Tất cả kho được phép';
                        });
                        _load(page: 1);
                      },
                      child: const Text('Bỏ lọc kho'),
                    ),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _size,
                      decoration: const InputDecoration(
                        labelText: 'Số biến động',
                      ),
                      items: [
                        for (final n in [10, 20, 50])
                          DropdownMenuItem(value: n, child: Text('$n')),
                      ],
                      onChanged: _busy
                          ? null
                          : (n) {
                              if (n != null) {
                                _size = n;
                                _load(page: 1);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_error!),
                        TextButton(
                          onPressed: () => _load(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data != null) ...[
                Text(
                  '${data.batch.batchNo} · ${data.batch.vaccineCode} · ${data.batch.vaccineName}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'NSX: ${data.batch.manufacturedAt ?? 'Chưa ghi nhận'} · HSD: ${data.batch.expiresAt}\n${expiryLabels[data.batch.expiryStatus] ?? data.batch.expiryStatus} · ${data.batch.daysToExpiry} ngày đến hạn',
                ),
                const SizedBox(height: 20),
                Text(
                  'Tồn theo kho được phép',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text(
                  'Đơn vị: lọ. Tồn vật lý, giữ chỗ và khả dụng do BE tính. Tổng theo kho không thay đổi khi chuyển trang biến động.',
                ),
                if (data.warehouses.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Chưa có tồn tại kho trong phạm vi đang xem.',
                      ),
                    ),
                  ),
                ...data.warehouses.map(
                  (w) => Card(
                    child: ListTile(
                      title: Text(w.name),
                      subtitle: Text(
                        'Tồn vật lý: ${w.onHand} · Giữ chỗ: ${w.reserved} · Khả dụng: ${w.available}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Lịch sử biến động',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (data.movements.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Chưa có biến động trong phạm vi đang xem.'),
                    ),
                  ),
                ...data.movements.map(
                  (m) => Card(
                    child: ListTile(
                      key: ValueKey('batch.movement.${m.id}'),
                      title: Text(
                        '${m.documentNo} · ${_source(m.sourceType)} · ${m.quantityDelta > 0 ? '+' : ''}${m.quantityDelta} lọ',
                      ),
                      subtitle: Text(
                        'Kho #${m.warehouseId} · Segment #${m.stockSegmentId}\nNgày nghiệp vụ: ${m.effectiveDate}\nGhi sổ: ${_posted(m.postedAt)}\nChứng từ #${m.sourceId} · Dòng #${m.sourceDetailId}',
                      ),
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${data.totalItems} biến động · Trang ${data.totalPages == 0 ? 0 : data.page}/${data.totalPages}',
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('batch.trace.previous'),
                          onPressed: _busy || _page <= 1
                              ? null
                              : () => _load(page: _page - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          key: const ValueKey('batch.trace.next'),
                          onPressed: _busy || _page >= data.totalPages
                              ? null
                              : () => _load(page: _page + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
