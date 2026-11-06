import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import 'data/catalog_repository.dart';
import 'manufacturer_picker.dart';

String catalogLabel(CatalogResource resource) =>
    resource == CatalogResource.organizations ? 'đối tác' : 'vaccine';
String catalogError(
  ApiException e,
  CatalogResource resource,
) => switch (e.statusCode) {
  401 => 'Phiên đã kết thúc. Vui lòng đăng nhập lại.',
  403 => 'Bạn không có quyền thay đổi danh mục này.',
  404 => 'Dữ liệu không còn tồn tại hoặc bạn không còn quyền truy cập.',
  412 =>
    'Dữ liệu đã được thay đổi bởi người khác. Hãy tải lại trước khi tiếp tục.',
  _ => switch (e.code) {
    'DUPLICATE_CODE' => 'Mã đã tồn tại. Vui lòng chọn mã khác.',
    'INVALID_MANUFACTURER' =>
      'Nhà sản xuất không còn hợp lệ. Vui lòng chọn lại từ danh mục.',
    'RESOURCE_IN_USE' =>
      resource == CatalogResource.organizations
          ? 'Đối tác đã được sử dụng; không thể xóa hay đổi mã/loại. Bạn có thể giữ nguyên các thông tin đó và sửa tên/quốc gia.'
          : 'Vaccine đã có lô; không thể xóa hay đổi mã, nhà sản xuất hoặc quy cách. Bạn vẫn có thể sửa tên và điều kiện bảo quản.',
    _ => e.message,
  },
};

// Preserve two decimal places rather than silently round a temperature that
// cannot be represented by Dart's JSON number. No product temperature default.
double? parseStorageTemperature(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^-?\d{1,16}(\.\d{1,2})?$').hasMatch(normalized)) return null;
  final number = double.tryParse(normalized);
  if (number == null || !number.isFinite) return null;
  BigInt cents(String s) {
    final negative = s.startsWith('-');
    final parts = s.replaceFirst('-', '').split('.');
    final result = BigInt.parse(
      '${parts[0]}${(parts.length == 1 ? '' : parts[1]).padRight(2, '0')}',
    );
    return negative ? -result : result;
  }

  return cents(normalized) == cents(number.toStringAsFixed(2)) ? number : null;
}

enum CatalogDialogAction { saved, refresh }

class CatalogDialogResult {
  const CatalogDialogResult(this.action, {this.storageReviewRequired = false});
  final CatalogDialogAction action;
  final bool storageReviewRequired;
}

class CatalogEditorDialog extends StatefulWidget {
  const CatalogEditorDialog({
    super.key,
    required this.repository,
    this.initial,
  });
  final CatalogRepository repository;
  final CatalogItem? initial;
  @override
  State<CatalogEditorDialog> createState() => _CatalogEditorDialogState();
}

class _CatalogEditorDialogState extends State<CatalogEditorDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController(),
      _name = TextEditingController(),
      _country = TextEditingController();
  final _manufacturer = TextEditingController(),
      _doses = TextEditingController(),
      _pack = TextEditingController();
  final _min = TextEditingController(), _max = TextEditingController();
  CatalogItem? _current;
  String? _kind, _error, _notice;
  int? _manufacturerId;
  bool _busy = false,
      _choosing = false,
      _reloadRequired = false,
      _missing = false,
      _uncertain = false;
  bool get _vaccine => widget.repository.resource == CatalogResource.vaccines;
  String get _prefix => widget.repository.path;
  @override
  void initState() {
    super.initState();
    _setFields(widget.initial);
  }

  void _setFields(CatalogItem? item) {
    _current = item;
    _code.text = item?.code ?? '';
    _name.text = item?.name ?? '';
    _country.text = item?.country ?? '';
    _kind = item?.kind;
    _manufacturerId = item?.manufacturerId;
    _manufacturer.text = item?.manufacturerName ?? '';
    _doses.text = item?.dosesPerVial?.toString() ?? '';
    _pack.text = item?.vialsPerPack?.toString() ?? '';
    _min.text = item?.storageMin?.toString() ?? '';
    _max.text = item?.storageMax?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _name,
      _country,
      _manufacturer,
      _doses,
      _pack,
      _min,
      _max,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Trường này không được để trống.'
      : value.length > 200
      ? 'Tối đa 200 ký tự.'
      : null;
  String? _integer(String? value) {
    final n = int.tryParse(value ?? '');
    return n == null || n <= 0 || n > 2147483647
        ? 'Nhập số nguyên từ 1 đến 2147483647.'
        : null;
  }

  Future<void> _chooseManufacturer() async {
    if (_busy || _choosing) return;
    setState(() => _choosing = true);
    try {
      final selected = await showDialog<CatalogItem>(
        context: context,
        useRootNavigator: false,
        builder: (_) => ManufacturerPicker(api: widget.repository.api),
      );
      if (!mounted || selected == null) return;
      setState(() {
        _manufacturerId = selected.id;
        _manufacturer.text = selected.name;
      });
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  Future<void> _save() async {
    if (_busy ||
        _choosing ||
        _reloadRequired ||
        _missing ||
        _uncertain ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final body = <String, Object?>{
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      if (!_vaccine) ...{
        'country': _country.text.trim().toUpperCase(),
        'kind': _kind,
      },
      if (_vaccine) ...{
        'manufacturerId': _manufacturerId,
        'dosesPerVial': int.parse(_doses.text),
        'vialsPerPack': int.parse(_pack.text),
        'storageMin': parseStorageTemperature(_min.text),
        'storageMax': parseStorageTemperature(_max.text),
      },
    };
    try {
      final result = _current == null
          ? await widget.repository.create(body)
          : await widget.repository.update(_current!, body);
      if (mounted) {
        Navigator.of(context).pop(
          CatalogDialogResult(
            CatalogDialogAction.saved,
            storageReviewRequired: result.storageReviewRequired,
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = catalogError(e, widget.repository.resource);
        _missing = e.statusCode == 404;
        _reloadRequired = e.statusCode == 412;
        if (e.statusCode == null || (e.statusCode ?? 0) >= 500) {
          if (_current == null) {
            _uncertain = true;
            _error = 'Chưa xác nhận được kết quả tạo. Đóng và tải lại danh sách trước khi thử lại.';
          } else {
            _reloadRequired = true;
          }
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Chưa xác nhận được kết quả lưu. Vui lòng đóng và tải lại danh sách.';
          _uncertain = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_busy || _current == null) return;
    setState(() => _busy = true);
    try {
      final latest = await widget.repository.get(_current!.id);
      if (mounted) {
        setState(() {
          _setFields(latest);
          _reloadRequired = false;
          _error = null;
          _notice = 'Đã tải bản mới nhất. Kiểm tra rồi lưu lại.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = catalogError(e, widget.repository.resource);
          _missing = e.statusCode == 404;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải lại dữ liệu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _temperatureChanged =>
      _vaccine &&
      _current != null &&
      (parseStorageTemperature(_min.text) != _current!.storageMin ||
          parseStorageTemperature(_max.text) != _current!.storageMax);
  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_missing;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          '${_current == null ? 'Thêm' : 'Sửa'} ${catalogLabel(widget.repository.resource)}',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: ValueKey('$_prefix.editor.code'),
                    controller: _code,
                    enabled: enabled,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Mã'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: ValueKey('$_prefix.editor.name'),
                    controller: _name,
                    enabled: enabled,
                    maxLength: 200,
                    decoration: const InputDecoration(labelText: 'Tên'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  if (!_vaccine) ...[
                    TextFormField(
                      key: const ValueKey('organizations.editor.country'),
                      controller: _country,
                      enabled: enabled,
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Mã quốc gia',
                        hintText: 'Ví dụ: VN',
                      ),
                      validator: (value) =>
                          RegExp(r'^[a-zA-Z]{2}$').hasMatch(value ?? '')
                          ? null
                          : 'Nhập mã quốc gia gồm hai chữ cái.',
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'organizations.editor.kind.${_current?.version ?? 'new'}',
                      ),
                      initialValue: _kind,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Loại đối tác',
                      ),
                      items: [
                        for (final entry in organizationKinds.entries)
                          DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: enabled
                          ? (value) => setState(() => _kind = value)
                          : null,
                      validator: (value) =>
                          value == null ? 'Chọn loại đối tác.' : null,
                    ),
                  ] else ...[
                    TextFormField(
                      key: const ValueKey('vaccines.editor.manufacturer'),
                      controller: _manufacturer,
                      readOnly: true,
                      enabled: enabled && !_choosing,
                      decoration: const InputDecoration(
                        labelText: 'Nhà sản xuất',
                        suffixIcon: Icon(Icons.search),
                      ),
                      onTap: _chooseManufacturer,
                      validator: (_) => _manufacturerId == null
                          ? 'Chọn nhà sản xuất từ danh mục.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('vaccines.editor.doses'),
                      controller: _doses,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Số liều / lọ',
                      ),
                      validator: _integer,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('vaccines.editor.pack'),
                      controller: _pack,
                      enabled: enabled,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Số lọ / hộp',
                      ),
                      validator: _integer,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('vaccines.editor.min'),
                      controller: _min,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nhiệt độ tối thiểu (°C)',
                      ),
                      validator: (v) => parseStorageTemperature(v ?? '') == null
                          ? 'Nhập nhiệt độ chính xác, tối đa 2 số thập phân.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const ValueKey('vaccines.editor.max'),
                      controller: _max,
                      enabled: enabled,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Nhiệt độ tối đa (°C)',
                      ),
                      validator: (v) {
                        final max = parseStorageTemperature(v ?? ''),
                            min = parseStorageTemperature(_min.text);
                        if (max == null) {
                          return 'Nhập nhiệt độ chính xác, tối đa 2 số thập phân.';
                        }
                        return min != null && max <= min
                            ? 'Nhiệt độ tối đa phải lớn hơn tối thiểu.'
                            : null;
                      },
                    ),
                    if (_temperatureChanged)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Đổi điều kiện bảo quản cần được rà soát với các lô và hàng đang có.',
                        ),
                      ),
                  ],
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
                      key: ValueKey('$_prefix.editor.reload'),
                      onPressed: _busy ? null : _reload,
                      child: const Text('Tải lại và bỏ thay đổi chưa lưu'),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.of(context).pop(
                    _missing || _uncertain || _reloadRequired
                        ? const CatalogDialogResult(CatalogDialogAction.refresh)
                        : null,
                  ),
            child: const Text('Đóng'),
          ),
          FilledButton(
            key: ValueKey('$_prefix.editor.save'),
            onPressed:
                _busy || _choosing || _missing || _uncertain || _reloadRequired
                ? null
                : _save,
            child: Text(_busy ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}

class CatalogDeleteDialog extends StatefulWidget {
  const CatalogDeleteDialog({
    super.key,
    required this.repository,
    required this.initial,
  });
  final CatalogRepository repository;
  final CatalogItem initial;
  @override
  State<CatalogDeleteDialog> createState() => _CatalogDeleteDialogState();
}

class _CatalogDeleteDialogState extends State<CatalogDeleteDialog> {
  late CatalogItem _current = widget.initial;
  bool _busy = false, _reload = false, _missing = false, _blocked = false;
  String? _error;
  Future<void> _delete() async {
    if (_busy || _reload || _missing || _blocked) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.delete(_current);
      if (mounted) {
        Navigator.of(context)
            .pop(const CatalogDialogResult(CatalogDialogAction.saved));
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = catalogError(e, widget.repository.resource);
          _missing = e.statusCode == 404;
          _reload =
              e.statusCode == 412 ||
              e.statusCode == null ||
              (e.statusCode ?? 0) >= 500;
          _blocked = e.statusCode == 403 || e.statusCode == 409;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Chưa xác nhận được kết quả xóa. Hãy tải lại trước khi tiếp tục.';
          _reload = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final latest = await widget.repository.get(_current.id);
      if (mounted) {
        setState(() {
          _current = latest;
          _reload = false;
          _error = 'Đã tải dữ liệu mới nhất. Xác nhận lại trước khi xóa.';
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = catalogError(e, widget.repository.resource);
          _missing = e.statusCode == 404;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được dữ liệu.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Xóa ${catalogLabel(widget.repository.resource)}?'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_current.code} · ${_current.name}'),
              const SizedBox(height: 12),
              const Text('Dữ liệu đã được sử dụng sẽ không thể xóa.'),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!),
                ),
              if (_reload && !_missing)
                TextButton(
                  key: ValueKey('${widget.repository.path}.delete.reload'),
                  onPressed: _busy ? null : _refresh,
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
                  _missing || _reload
                      ? const CatalogDialogResult(CatalogDialogAction.refresh)
                      : null,
                ),
          child: const Text('Đóng'),
        ),
        FilledButton(
          key: ValueKey('${widget.repository.path}.delete.confirm'),
          onPressed: _busy || _reload || _missing || _blocked ? null : _delete,
          child: Text(_busy ? 'Đang xóa…' : 'Xóa'),
        ),
      ],
    ),
  );
}
