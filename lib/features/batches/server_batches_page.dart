import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../auth/state/auth_controller.dart';
import 'batch_controller.dart';
import 'batch_dialog.dart';
import 'batch_repository.dart';
import 'batch_trace_page.dart';
import 'reference_picker.dart';

class ServerBatchesPage extends StatefulWidget {
  const ServerBatchesPage({
    super.key,
    required this.controller,
    required this.auth,
    required this.canManage,
  });
  final BatchController controller;
  final AuthController auth;
  final bool canManage;
  @override
  State<ServerBatchesPage> createState() => _ServerBatchesPageState();
}

class _ServerBatchesPageState extends State<ServerBatchesPage> {
  late final _search = TextEditingController(text: widget.controller.search);
  late final _before = TextEditingController(
    text: widget.controller.filters['expiresBefore'] ?? '',
  );
  late String? _expiry = widget.controller.filters['expiryStatus'];
  final _filtersForm = GlobalKey<FormState>();
  Timer? _timer;
  bool _opening = false;
  BatchController get _c => widget.controller;
  bool get _active => mounted && widget.auth.status == SessionStatus.signedIn;
  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _before.dispose();
    super.dispose();
  }

  void _apply() {
    _timer?.cancel();
    if (!_filtersForm.currentState!.validate()) return;
    _c.load(
      page: 1,
      search: _search.text,
      filters: {
        'vaccineId': ?_c.filters['vaccineId'],
        'expiryStatus': ?_expiry,
        if (_before.text.trim().isNotEmpty)
          'expiresBefore': _before.text.trim(),
      },
    );
  }

  Future<void> _vaccineFilter() async {
    final picked = await showDialog<BatchReference>(
      context: context,
      useRootNavigator: false,
      builder: (_) => BatchReferencePicker(api: _c.repository.api),
    );
    if (!_active || picked == null) return;
    _c.vaccineLabel = picked.label;
    _c.load(page: 1, filters: {..._c.filters, 'vaccineId': '${picked.id}'});
  }

  void _message(String s) {
    if (_active) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
    }
  }

  Future<void> _trace(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BatchTracePage(
          repository: _c.repository,
          batchId: id,
          auth: widget.auth,
        ),
      ),
    );
  }

  Future<void> _open({
    ServerBatch? item,
    bool delete = false,
    bool view = false,
  }) async {
    if (_opening || (!view && item != null && !widget.canManage)) return;
    setState(() => _opening = true);
    try {
      final detail = item == null ? null : await _c.repository.get(item.id);
      if (!mounted || !_active) return;
      setState(() => _opening = false);
      if (view) {
        await _trace(detail!.id);
        return;
      }
      final result = await showDialog<BatchDialogResult>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => BatchDialog(
          repository: _c.repository,
          initial: detail,
          delete: delete,
        ),
      );
      if (!_active || result == null) return;
      await _c.load(page: item == null ? 1 : null);
      if (!mounted || !_active) return;
      if (result.existingId != null) {
        await _trace(result.existingId!);
      }
    } on ApiException catch (e) {
      _message(batchError(e));
      if (_active && e.statusCode == 404) await _c.load();
    } catch (_) {
      _message('Không thể mở lô. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _actions(ServerBatch b) => Wrap(
    children: [
      IconButton(
        key: ValueKey('batches.trace.${b.id}'),
        tooltip: 'Chi tiết và truy xuất',
        onPressed: _opening ? null : () => _open(item: b, view: true),
        icon: const Icon(Icons.history),
      ),
      if (widget.canManage) ...[
        IconButton(
          key: ValueKey('batches.edit.${b.id}'),
          tooltip: 'Sửa ngày',
          onPressed: _opening ? null : () => _open(item: b),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: ValueKey('batches.delete.${b.id}'),
          tooltip: 'Xóa',
          onPressed: _opening ? null : () => _open(item: b, delete: true),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ],
  );
  String _expiryText(ServerBatch b) =>
      '${expiryLabels[b.expiryStatus] ?? b.expiryStatus} (${b.daysToExpiry} ngày đến hạn)';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final data = _c.data, compact = constraints.maxWidth < 800;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Lô vaccine',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  FilledButton.icon(
                    key: const ValueKey('batches.add'),
                    onPressed: _opening ? null : () => _open(),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm lô'),
                  ),
                ],
              ),
              const Text(
                'Danh mục metadata dùng chung. Tạo lô chưa làm tăng tồn kho. Hạn dùng do BE đánh giá theo ngày Việt Nam (UTC+7).',
              ),
              const SizedBox(height: 16),
              Form(
                key: _filtersForm,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        key: const ValueKey('batches.search'),
                        controller: _search,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Tìm số lô / mã, tên vaccine',
                          counterText: '',
                        ),
                        onFieldSubmitted: (_) => _apply(),
                        onChanged: (_) {
                          _timer?.cancel();
                          _timer = Timer(
                            const Duration(milliseconds: 350),
                            _apply,
                          );
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('batches.vaccineFilter'),
                      onPressed: _vaccineFilter,
                      icon: const Icon(Icons.vaccines_outlined),
                      label: Text(_c.vaccineLabel),
                    ),
                    if (_c.filters.containsKey('vaccineId'))
                      IconButton(
                        tooltip: 'Bỏ lọc vaccine',
                        onPressed: () {
                          _c.vaccineLabel = 'Tất cả vaccine';
                          _c.load(
                            page: 1,
                            filters: {..._c.filters}..remove('vaccineId'),
                          );
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: const ValueKey('batches.expiry'),
                        initialValue: _expiry,
                        decoration: const InputDecoration(
                          labelText: 'Trạng thái hạn',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          ...expiryLabels.entries.map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          _expiry = v;
                          _apply();
                        },
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextFormField(
                        key: const ValueKey('batches.before'),
                        controller: _before,
                        decoration: const InputDecoration(
                          labelText: 'HSD trước ngày (không gồm)',
                          hintText: 'YYYY-MM-DD',
                        ),
                        validator: (s) =>
                            (s ?? '').trim().isEmpty ||
                                validBatchDate(s!.trim()) != null
                            ? null
                            : 'Nhập ngày YYYY-MM-DD hợp lệ.',
                        onFieldSubmitted: (_) => _apply(),
                      ),
                    ),
                    SizedBox(
                      width: 170,
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _c.sort,
                        decoration: const InputDecoration(labelText: 'Sắp xếp'),
                        items: const [
                          DropdownMenuItem(
                            value: 'expiresAt',
                            child: Text('Hạn sử dụng'),
                          ),
                          DropdownMenuItem(
                            value: 'batchNo',
                            child: Text('Số lô'),
                          ),
                          DropdownMenuItem(value: 'id', child: Text('ID')),
                        ],
                        onChanged: _c.loading
                            ? null
                            : (v) {
                                if (v != null) _c.load(page: 1, sort: v);
                              },
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _c.pageSize,
                        decoration: const InputDecoration(labelText: 'Số dòng'),
                        items: [
                          for (final n in [10, 20, 50])
                            DropdownMenuItem(value: n, child: Text('$n')),
                        ],
                        onChanged: _c.loading
                            ? null
                            : (n) {
                                if (n != null) _c.load(page: 1, pageSize: n);
                              },
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('batches.reload'),
                      tooltip: 'Áp dụng bộ lọc / tải lại',
                      onPressed: _c.loading ? null : _apply,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_c.loading || _opening) const LinearProgressIndicator(),
              if (_c.error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(_c.error!),
                        TextButton(
                          onPressed: () => _c.load(),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data != null && data.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không có lô phù hợp.'),
                  ),
                ),
              if (data != null && data.items.isNotEmpty)
                Card(
                  child: compact
                      ? Column(
                          children: [
                            for (final b in data.items)
                              Column(
                                children: [
                                  ListTile(
                                    title: Text(b.batchNo),
                                    subtitle: Text(
                                      '${b.vaccineCode} · ${b.vaccineName}\nNSX: ${b.manufacturedAt ?? 'Chưa ghi nhận'} · HSD: ${b.expiresAt}\n${_expiryText(b)}',
                                    ),
                                    onTap: () => _open(item: b, view: true),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _actions(b),
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
                              DataColumn(label: Text('Số lô')),
                              DataColumn(label: Text('Vaccine')),
                              DataColumn(label: Text('NSX')),
                              DataColumn(label: Text('HSD')),
                              DataColumn(label: Text('Trạng thái')),
                              DataColumn(label: Text('Thao tác')),
                            ],
                            rows: [
                              for (final b in data.items)
                                DataRow(
                                  cells: [
                                    DataCell(Text(b.batchNo)),
                                    DataCell(
                                      Text(
                                        '${b.vaccineCode} · ${b.vaccineName}',
                                      ),
                                    ),
                                    DataCell(Text(b.manufacturedAt ?? '—')),
                                    DataCell(Text(b.expiresAt)),
                                    DataCell(Text(_expiryText(b))),
                                    DataCell(_actions(b)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                ),
              if (data != null)
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${data.totalItems} lô · Trang ${data.totalPages == 0 ? 0 : _c.page}/${data.totalPages}',
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('batches.previous'),
                          onPressed: _c.loading || _c.page <= 1
                              ? null
                              : () => _c.load(page: _c.page - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          key: const ValueKey('batches.next'),
                          onPressed: _c.loading || _c.page >= data.totalPages
                              ? null
                              : () => _c.load(page: _c.page + 1),
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
    ),
  );
}
