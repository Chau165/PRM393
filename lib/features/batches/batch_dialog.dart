import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'batch_repository.dart';
import 'reference_picker.dart';

String batchError(ApiException e) => switch (e.statusCode) {
  403 => 'Bạn không có quyền thực hiện thao tác này.',
  404 => 'Lô không còn tồn tại hoặc không còn quyền truy cập.',
  412 => 'Lô đã được người khác thay đổi. Hãy tải lại và kiểm tra trước khi tiếp tục.',
  _ => switch (e.code) {
    'RESOURCE_IN_USE' =>
      'Lô đã được dùng trên phiếu nhập (kể cả nháp), không thể sửa hoặc xóa.',
    'DUPLICATE_CODE' => 'Lô này đã tồn tại. Bạn có thể mở lô hiện có.',
    'BATCH_METADATA_CONFLICT' => 'Số lô đã tồn tại với ngày sản xuất hoặc hạn dùng khác. Không tự ghi đè; hãy kiểm tra lô hiện có.',
    'INVENTORY_INTEGRITY_ERROR' => 'Dữ liệu tồn hoặc nguồn biến động không nhất quán. Cần kiểm tra dữ liệu với quản trị viên.',
    _ => e.message,
  },
};

class BatchDialogResult {
  const BatchDialogResult({this.existingId});
  final int? existingId;
}

class BatchDialog extends StatefulWidget {
  const BatchDialog({
    super.key,
    required this.repository,
    this.initial,
    this.delete = false,
  });
  final BatchRepository repository;
  final ServerBatch? initial;
  final bool delete;
  @override
  State<BatchDialog> createState() => _BatchDialogState();
}

class _BatchDialogState extends State<BatchDialog> {
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController(),
      _vaccine = TextEditingController(),
      _manufactured = TextEditingController(),
      _expires = TextEditingController();
  ServerBatch? _current;
  int? _vaccineId, _existingId;
  bool _busy = false,
      _reload = false,
      _uncertain = false,
      _missing = false,
      _blocked = false;
  String? _error, _notice;
  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _fill(widget.initial!);
  }

  void _fill(ServerBatch b) {
    _current = b;
    _number.text = b.batchNo;
    _vaccine.text = '${b.vaccineCode} · ${b.vaccineName}';
    _vaccineId = b.vaccineId;
    _manufactured.text = b.manufacturedAt ?? '';
    _expires.text = b.expiresAt;
  }

  @override
  void dispose() {
    _number.dispose();
    _vaccine.dispose();
    _manufactured.dispose();
    _expires.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final picked = await showDialog<BatchReference>(
      context: context,
      useRootNavigator: false,
      builder: (_) => BatchReferencePicker(api: widget.repository.api),
    );
    if (mounted && picked != null) {
      setState(() {
        _vaccineId = picked.id;
        _vaccine.text = picked.label;
      });
    }
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final b = await widget.repository.get(_current!.id);
      if (mounted) {
        setState(() {
          _fill(b);
          _reload = false;
          _uncertain = false;
          _error = null;
          _notice = 'Đã tải bản mới nhất. Kiểm tra lại trước khi xác nhận.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = batchError(e);
          _missing = e.statusCode == 404;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải lại lô.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _reload || _uncertain || _missing || _blocked) return;
    if (!widget.delete && !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _existingId = null;
    });
    try {
      if (widget.delete) {
        await widget.repository.delete(_current!);
      } else {
        final manufactured = _manufactured.text.trim().isEmpty
            ? null
            : _manufactured.text.trim();
        if (_current == null) {
          await widget.repository.create(
            vaccineId: _vaccineId!,
            batchNo: _number.text,
            manufacturedAt: manufactured,
            expiresAt: _expires.text.trim(),
          );
        } else {
          await widget.repository.update(
            _current!,
            manufacturedAt: manufactured,
            expiresAt: _expires.text.trim(),
          );
        }
      }
      if (mounted) Navigator.of(context).pop(const BatchDialogResult());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = batchError(e);
        _missing = e.statusCode == 404;
        _reload = e.statusCode == 412;
        _blocked = e.code == 'RESOURCE_IN_USE';
        _existingId = e.existingBatchId;
        if (e.statusCode == null || (e.statusCode ?? 0) >= 500) {
          if (_current == null) {
            _uncertain = true;
            _error = 'Chưa xác nhận được kết quả tạo. Đóng và kiểm tra danh sách trước khi thử lại.';
          } else {
            _reload = true;
            _error = 'Chưa xác nhận được kết quả. Hãy tải lại và kiểm tra trước khi tiếp tục.';
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _uncertain = true;
          _error =
              'Chưa xác nhận được kết quả. Hãy đóng và kiểm tra danh sách.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _date(String? text, {bool optional = false}) {
    final s = text?.trim() ?? '';
    if (optional && s.isEmpty) return null;
    return validBatchDate(s) == null
        ? 'Nhập ngày hợp lệ dạng YYYY-MM-DD.'
        : null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(
        widget.delete
            ? 'Xóa lô vaccine'
            : _current == null
            ? 'Thêm lô vaccine'
            : 'Sửa ngày của lô',
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (widget.delete)
                Text(
                  'Xóa lô ${_current!.batchNo} của ${_current!.vaccineName}? Chỉ xóa được lô chưa dùng trên phiếu nhập.',
                )
              else
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        key: const ValueKey('batch.editor.vaccine'),
                        controller: _vaccine,
                        readOnly: true,
                        onTap: _current == null && !_busy ? _choose : null,
                        decoration: const InputDecoration(
                          labelText: 'Vaccine',
                          suffixIcon: Icon(Icons.search),
                        ),
                        validator: (_) =>
                            _vaccineId == null ? 'Chọn vaccine.' : null,
                      ),
                      TextFormField(
                        key: const ValueKey('batch.editor.number'),
                        controller: _number,
                        enabled: _current == null && !_busy,
                        maxLength: 200,
                        decoration: const InputDecoration(labelText: 'Số lô'),
                        validator: (s) =>
                            (s ?? '').trim().isEmpty ? 'Nhập số lô.' : null,
                      ),
                      TextFormField(
                        key: const ValueKey('batch.editor.manufactured'),
                        controller: _manufactured,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Ngày sản xuất (có thể bỏ trống)',
                          hintText: 'YYYY-MM-DD',
                        ),
                        validator: (s) => _date(s, optional: true),
                      ),
                      TextFormField(
                        key: const ValueKey('batch.editor.expires'),
                        controller: _expires,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          labelText: 'Hạn sử dụng',
                          hintText: 'YYYY-MM-DD',
                        ),
                        validator: (s) {
                          final error = _date(s);
                          if (error != null) return error;
                          final m = validBatchDate(_manufactured.text.trim());
                          return m != null && m.compareTo(s!.trim()) > 0
                              ? 'Hạn dùng phải từ ngày sản xuất trở đi.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ngày YYYY-MM-DD. Có thể ghi nhận lô hết hạn; việc tạo lô không nhập tồn và không cho phép xuất hàng hết hạn.',
                      ),
                      if (_current != null)
                        const Text(
                          'Vaccine và số lô cố định. Lô đã được dùng trên phiếu nhập không thể sửa ngày.',
                        ),
                    ],
                  ),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_notice!),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_reload && !_missing)
                TextButton(
                  key: const ValueKey('batch.editor.reload'),
                  onPressed: _busy ? null : _load,
                  child: const Text('Tải lại và bỏ thay đổi chưa lưu'),
                ),
              if (_existingId != null)
                TextButton(
                  key: const ValueKey('batch.editor.existing'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context)
                            .pop(BatchDialogResult(existingId: _existingId)),
                  child: const Text('Mở lô hiện có'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => Navigator.of(context).pop(
                  (_uncertain || _missing) ? const BatchDialogResult() : null,
                ),
          child: const Text('Đóng'),
        ),
        FilledButton(
          key: const ValueKey('batch.editor.save'),
          onPressed: _busy || _reload || _uncertain || _missing || _blocked
              ? null
              : _save,
          child: Text(widget.delete ? 'Xóa' : 'Lưu'),
        ),
      ],
    ),
  );
}
