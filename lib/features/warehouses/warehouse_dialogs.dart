import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'data/warehouse_repository.dart';

enum WarehouseDialogResult { saved, refresh }

String warehouseError(ApiException e) => switch (e.statusCode) {
  401 => 'Phiên đã kết thúc. Vui lòng đăng nhập lại.',
  403 => 'Bạn không có quyền thay đổi thông tin kho.',
  404 => 'Kho không còn tồn tại hoặc bạn không còn quyền truy cập.',
  412 => 'Kho đã được thay đổi bởi người khác. Hãy tải lại trước khi tiếp tục.',
  _ => switch (e.code) {
    'DUPLICATE_CODE' => 'Mã kho đã tồn tại. Vui lòng chọn mã khác.',
    'RESOURCE_IN_USE' => 'Kho đã được phân quyền hoặc có chứng từ. Không thể xóa hay đổi mã; bạn vẫn có thể sửa tên.',
    _ => e.message,
  },
};

class WarehouseEditorDialog extends StatefulWidget {
  const WarehouseEditorDialog({
    super.key,
    required this.repository,
    this.initial,
  });
  final WarehouseRepository repository;
  final ServerWarehouse? initial;
  @override
  State<WarehouseEditorDialog> createState() => _WarehouseEditorDialogState();
}

class _WarehouseEditorDialogState extends State<WarehouseEditorDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.initial?.code ?? '');
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late ServerWarehouse? _current = widget.initial;
  bool _saving = false,
      _reloadRequired = false,
      _missing = false,
      _uncertainCreate = false;
  String? _error, _notice;
  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  String? _validate(String? value) => value == null || value.trim().isEmpty
      ? 'Trường này không được để trống.'
      : value.length > 200
      ? 'Tối đa 200 ký tự.'
      : null;

  Future<void> _save() async {
    if (_saving ||
        _reloadRequired ||
        _missing ||
        _uncertainCreate ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_current == null) {
        await widget.repository.create(_code.text, _name.text);
      } else {
        await widget.repository.update(_current!, _code.text, _name.text);
      }
      if (mounted) Navigator.of(context).pop(WarehouseDialogResult.saved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = warehouseError(e);
        _reloadRequired = e.statusCode == 412;
        _missing = e.statusCode == 404;
        if (e.statusCode == null || (e.statusCode ?? 0) >= 500) {
          if (_current == null) {
            _uncertainCreate = true;
            _error = 'Chưa xác nhận được kết quả tạo kho. Đóng và tải lại danh sách trước khi thử lại.';
          } else {
            _reloadRequired = true;
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Chưa xác nhận được kết quả lưu. Vui lòng đóng và tải lại danh sách.';
          _uncertainCreate = true;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reload() async {
    if (_saving || _current == null) return;
    setState(() => _saving = true);
    try {
      final latest = await widget.repository.get(_current!.id);
      if (!mounted) return;
      setState(() {
        _current = latest;
        _code.text = latest.code;
        _name.text = latest.name;
        _reloadRequired = false;
        _error = null;
        _notice = 'Đã tải bản mới nhất. Kiểm tra thông tin rồi lưu lại.';
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = warehouseError(e);
          _missing = e.statusCode == 404;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải lại thông tin kho.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(_current == null ? 'Thêm kho' : 'Sửa kho'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const ValueKey('warehouses.editor.code'),
                  controller: _code,
                  enabled: !_saving && !_missing,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Mã kho'),
                  validator: _validate,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('warehouses.editor.name'),
                  controller: _name,
                  enabled: !_saving && !_missing,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: 'Tên kho'),
                  validator: _validate,
                  onFieldSubmitted: (_) => _save(),
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
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_notice!),
                  ),
                if (_reloadRequired && !_missing)
                  TextButton(
                    key: const ValueKey('warehouses.editor.reload'),
                    onPressed: _saving ? null : _reload,
                    child: const Text('Tải lại và bỏ thay đổi chưa lưu'),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(
                  _missing || _uncertainCreate || _reloadRequired
                      ? WarehouseDialogResult.refresh
                      : null,
                ),
          child: const Text('Đóng'),
        ),
        FilledButton(
          key: const ValueKey('warehouses.editor.save'),
          onPressed: _saving || _reloadRequired || _missing || _uncertainCreate
              ? null
              : _save,
          child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
        ),
      ],
    ),
  );
}

class WarehouseDeleteDialog extends StatefulWidget {
  const WarehouseDeleteDialog({
    super.key,
    required this.repository,
    required this.initial,
  });
  final WarehouseRepository repository;
  final ServerWarehouse initial;
  @override
  State<WarehouseDeleteDialog> createState() => _WarehouseDeleteDialogState();
}

class _WarehouseDeleteDialogState extends State<WarehouseDeleteDialog> {
  late ServerWarehouse _current = widget.initial;
  bool _busy = false,
      _reloadRequired = false,
      _missing = false,
      _blocked = false;
  String? _error;
  Future<void> _delete() async {
    if (_busy || _reloadRequired || _missing || _blocked) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.delete(_current);
      if (mounted) Navigator.of(context).pop(WarehouseDialogResult.saved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = warehouseError(e);
          _missing = e.statusCode == 404;
          _reloadRequired =
              e.statusCode == 412 ||
              e.statusCode == null ||
              (e.statusCode ?? 0) >= 500;
          _blocked = e.statusCode == 409 || e.statusCode == 403;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Chưa xác nhận được kết quả xóa. Hãy tải lại trước khi tiếp tục.';
          _reloadRequired = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final latest = await widget.repository.get(_current.id);
      if (mounted) {
        setState(() {
          _current = latest;
          _reloadRequired = false;
          _error = 'Đã tải thông tin mới nhất. Xác nhận lại trước khi xóa.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = warehouseError(e);
          _missing = e.statusCode == 404;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải lại thông tin kho.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Xóa kho?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_current.code} · ${_current.name}'),
              const SizedBox(height: 12),
              const Text(
                'Kho đã được phân quyền hoặc có chứng từ sẽ không thể xóa.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!),
                ),
              if (_reloadRequired && !_missing)
                TextButton(
                  key: const ValueKey('warehouses.delete.reload'),
                  onPressed: _busy ? null : _reload,
                  child: const Text('Tải lại thông tin mới nhất'),
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
                  _missing || _reloadRequired
                      ? WarehouseDialogResult.refresh
                      : null,
                ),
          child: const Text('Đóng'),
        ),
        FilledButton(
          key: const ValueKey('warehouses.delete.confirm'),
          onPressed: _busy || _reloadRequired || _missing || _blocked
              ? null
              : _delete,
          child: Text(_busy ? 'Đang xóa…' : 'Xóa kho'),
        ),
      ],
    ),
  );
}
