import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../auth/state/auth_controller.dart';
import 'catalog_dialogs.dart';
import 'data/catalog_repository.dart';
import 'manufacturer_picker.dart';
import 'state/catalog_controller.dart';

class ServerCatalogPage extends StatefulWidget {
  const ServerCatalogPage({
    super.key,
    required this.controller,
    required this.auth,
    required this.canManage,
  });
  final CatalogController controller;
  final AuthController auth;
  final bool canManage;
  @override
  State<ServerCatalogPage> createState() => _ServerCatalogPageState();
}

class _ServerCatalogPageState extends State<ServerCatalogPage> {
  late final _search = TextEditingController(text: widget.controller.search);
  late final _country = TextEditingController(
    text: widget.controller.filters['country'] ?? '',
  );
  late String? _kind = widget.controller.filters['kind'];
  Timer? _debounce;
  bool _opening = false, _reviewNotice = false;
  CatalogController get _c => widget.controller;
  CatalogRepository get _repository => _c.repository;
  bool get _vaccine => _repository.resource == CatalogResource.vaccines;
  String get _prefix => _repository.path;
  bool get _active => mounted && widget.auth.status == SessionStatus.signedIn;
  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _country.dispose();
    super.dispose();
  }

  void _apply() {
    _debounce?.cancel();
    final country = _country.text.trim().toUpperCase();
    if (!_vaccine && country.length == 1) return;
    _c.load(
      page: 1,
      search: _search.text,
      filters: _vaccine
          ? Map.of(_c.filters)
          : {'kind': ?_kind, if (country.isNotEmpty) 'country': country},
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _apply);
  }

  void _message(String message) {
    if (_active) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _manufacturerFilter() async {
    final selected = await showDialog<CatalogItem>(
      context: context,
      useRootNavigator: false,
      builder: (_) => ManufacturerPicker(api: _repository.api),
    );
    if (!_active || selected == null) return;
    _c.manufacturerFilterLabel = selected.name;
    _c.load(page: 1, filters: {'manufacturerId': '${selected.id}'});
  }

  List<Widget> _details(CatalogItem item) => [
    Text('Mã: ${item.code}'),
    const SizedBox(height: 8),
    Text('Tên: ${item.name}'),
    const SizedBox(height: 8),
    if (!_vaccine) ...[
      Text('Quốc gia: ${item.country}'),
      Text('Loại: ${organizationKinds[item.kind] ?? item.kind}'),
    ] else ...[
      Text('Nhà sản xuất: ${item.manufacturerName}'),
      Text('${item.dosesPerVial} liều/lọ · ${item.vialsPerPack} lọ/hộp'),
      Text('Bảo quản: ${item.storageMin} đến ${item.storageMax} °C'),
    ],
  ];
  Future<void> _open({
    CatalogItem? item,
    bool delete = false,
    bool viewOnly = false,
  }) async {
    if (_opening || (!viewOnly && !widget.canManage)) return;
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
            title: Text('Thông tin ${catalogLabel(_repository.resource)}'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _details(detail!),
                ),
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
      final result = await showDialog<CatalogDialogResult>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (_) => delete
            ? CatalogDeleteDialog(repository: _repository, initial: detail!)
            : CatalogEditorDialog(repository: _repository, initial: detail),
      );
      if (!_active || result == null) return;
      if (result.storageReviewRequired) setState(() => _reviewNotice = true);
      await _c.load(page: item == null ? 1 : null);
      if (result.action == CatalogDialogAction.saved) {
        _message(
          delete
              ? 'Đã xóa ${catalogLabel(_repository.resource)}.'
              : 'Đã lưu ${catalogLabel(_repository.resource)}.',
        );
      }
    } on ApiException catch (e) {
      _message(catalogError(e, _repository.resource));
      if (_active && e.statusCode == 404) await _c.load();
    } catch (_) {
      _message('Không thể mở dữ liệu. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _actions(CatalogItem item) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: ValueKey('$_prefix.view.${item.id}'),
        tooltip: 'Xem chi tiết',
        onPressed: _opening ? null : () => _open(item: item, viewOnly: true),
        icon: const Icon(Icons.info_outline),
      ),
      if (widget.canManage) ...[
        IconButton(
          key: ValueKey('$_prefix.edit.${item.id}'),
          tooltip: 'Sửa',
          onPressed: _opening ? null : () => _open(item: item),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: ValueKey('$_prefix.delete.${item.id}'),
          tooltip: 'Xóa',
          onPressed: _opening ? null : () => _open(item: item, delete: true),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ],
  );
  Widget _table(List<CatalogItem> items) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: [
        const DataColumn(label: Text('Mã')),
        const DataColumn(label: Text('Tên')),
        if (!_vaccine) ...[
          const DataColumn(label: Text('Loại')),
          const DataColumn(label: Text('Quốc gia')),
        ] else ...[
          const DataColumn(label: Text('Nhà sản xuất')),
          const DataColumn(label: Text('Quy cách')),
          const DataColumn(label: Text('Bảo quản (°C)')),
        ],
        const DataColumn(label: Text('Thao tác')),
      ],
      rows: [
        for (final item in items)
          DataRow(
            cells: [
              DataCell(Text(item.code)),
              DataCell(Text(item.name)),
              if (!_vaccine) ...[
                DataCell(Text(organizationKinds[item.kind] ?? item.kind!)),
                DataCell(Text(item.country!)),
              ] else ...[
                DataCell(Text(item.manufacturerName!)),
                DataCell(
                  Text(
                    '${item.dosesPerVial} liều/lọ · ${item.vialsPerPack} lọ/hộp',
                  ),
                ),
                DataCell(Text('${item.storageMin} → ${item.storageMax}')),
              ],
              DataCell(_actions(item)),
            ],
          ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Text(
                    _vaccine ? 'Danh mục vaccine' : 'Danh mục đối tác',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (widget.canManage)
                    FilledButton.icon(
                      key: ValueKey('$_prefix.add'),
                      onPressed: _opening ? null : () => _open(),
                      icon: const Icon(Icons.add),
                      label: Text('Thêm ${catalogLabel(_repository.resource)}'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (_reviewNotice)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Đã đổi điều kiện bảo quản. Cần rà soát các lô và hàng hiện có theo quy trình của đơn vị. Thay đổi này không tự giải phóng hay cách ly hàng.',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Đóng thông báo',
                          onPressed: () =>
                              setState(() => _reviewNotice = false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: compact ? constraints.maxWidth - 32 : 300,
                    child: TextField(
                      key: ValueKey('$_prefix.search'),
                      controller: _search,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Tìm mã hoặc tên',
                        counterText: '',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => _schedule(),
                      onSubmitted: (_) => _apply(),
                    ),
                  ),
                  if (!_vaccine) ...[
                    SizedBox(
                      width: 235,
                      child: DropdownButtonFormField<String>(
                        key: const ValueKey('organizations.kindFilter'),
                        initialValue: _kind ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại đối tác',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Tất cả loại'),
                          ),
                          for (final entry in organizationKinds.entries)
                            DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                        ],
                        onChanged: _c.loading
                            ? null
                            : (value) {
                                setState(
                                  () => _kind = value == '' ? null : value,
                                );
                                _apply();
                              },
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        key: const ValueKey('organizations.countryFilter'),
                        controller: _country,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                        ],
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Quốc gia',
                          hintText: 'VN',
                          counterText: '',
                        ),
                        onChanged: (_) => _schedule(),
                        onSubmitted: (_) => _apply(),
                      ),
                    ),
                  ] else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: OutlinedButton.icon(
                            key: const ValueKey('vaccines.manufacturerFilter'),
                            onPressed: _manufacturerFilter,
                            icon: const Icon(Icons.factory_outlined),
                            label: Text(
                              _c.manufacturerFilterLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (_c.filters.containsKey('manufacturerId'))
                          IconButton(
                            tooltip: 'Bỏ lọc nhà sản xuất',
                            onPressed: () {
                              _c.manufacturerFilterLabel =
                                  'Tất cả nhà sản xuất';
                              _c.load(page: 1, filters: {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                      ],
                    ),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('$_prefix.sort'),
                      initialValue: _c.sort,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Sắp xếp'),
                      items: const [
                        DropdownMenuItem(value: 'code', child: Text('Mã')),
                        DropdownMenuItem(value: 'name', child: Text('Tên')),
                      ],
                      onChanged: _c.loading
                          ? null
                          : (value) {
                              if (value != null) _c.load(page: 1, sort: value);
                            },
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('$_prefix.pageSize'),
                      initialValue: _c.pageSize,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Số dòng'),
                      items: [
                        for (final size in [10, 20, 50])
                          DropdownMenuItem(value: size, child: Text('$size')),
                      ],
                      onChanged: _c.loading
                          ? null
                          : (value) {
                              if (value != null) {
                                _c.load(page: 1, pageSize: value);
                              }
                            },
                    ),
                  ),
                  IconButton(
                    key: ValueKey('$_prefix.reload'),
                    tooltip: 'Tải lại',
                    onPressed: _c.loading ? null : _apply,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_c.loading || _opening) const LinearProgressIndicator(),
              if (_c.error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                )
              else if (!_c.loading && _c.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(36),
                    child: Text(
                      'Không có dữ liệu phù hợp.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (_c.items.isNotEmpty)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: compact
                      ? Column(
                          children: [
                            for (final item in _c.items)
                              Column(
                                children: [
                                  ListTile(
                                    title: Text(item.name),
                                    subtitle: Text(
                                      '${item.code}\n${_vaccine ? '${item.manufacturerName} · ${item.storageMin} → ${item.storageMax} °C' : '${organizationKinds[item.kind]} · ${item.country}'}',
                                    ),
                                    onTap: () =>
                                        _open(item: item, viewOnly: true),
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
                      : _table(_c.items),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${_c.totalItems} kết quả · Trang ${_c.totalPages == 0 ? 0 : _c.page}/${_c.totalPages}',
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('$_prefix.previous'),
                        tooltip: 'Trang trước',
                        onPressed: _c.loading || _c.page <= 1
                            ? null
                            : () => _c.load(page: _c.page - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        key: ValueKey('$_prefix.next'),
                        tooltip: 'Trang sau',
                        onPressed: _c.loading || _c.page >= _c.totalPages
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
