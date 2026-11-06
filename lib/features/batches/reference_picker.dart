import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../catalog/data/catalog_repository.dart';
import '../warehouses/data/warehouse_repository.dart';

class BatchReference {
  const BatchReference(this.id, this.label);
  final int id;
  final String label;
}

// Both lookups query all server pages instead of treating page one as a catalog.
class BatchReferencePicker extends StatefulWidget {
  const BatchReferencePicker({
    super.key,
    required this.api,
    this.warehouses = false,
  });
  final ApiClient api;
  final bool warehouses;
  @override
  State<BatchReferencePicker> createState() => _BatchReferencePickerState();
}

class _BatchReferencePickerState extends State<BatchReferencePicker> {
  final _search = TextEditingController();
  Timer? _timer;
  int _page = 1, _pages = 0, _generation = 0;
  bool _busy = false;
  String? _error;
  List<BatchReference> _items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    _timer?.cancel();
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _items = [];
      _page = page;
    });
    try {
      List<BatchReference> items;
      int pages;
      if (widget.warehouses) {
        final r = await WarehouseRepository(widget.api)
            .list(page: page, search: _search.text);
        items = r.items
            .map((x) => BatchReference(x.id, '${x.code} · ${x.name}'))
            .toList();
        pages = r.totalPages;
      } else {
        final r = await CatalogRepository(
          widget.api,
          CatalogResource.vaccines,
        ).list(page: page, search: _search.text);
        items = r.items
            .map((x) => BatchReference(x.id, '${x.code} · ${x.name}'))
            .toList();
        pages = r.totalPages;
      }
      if (mounted && generation == _generation) {
        setState(() {
          _items = items;
          _pages = pages;
        });
      }
    } on ApiException catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Không đọc được danh mục.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.warehouses ? 'Chọn kho' : 'Chọn vaccine'),
    content: SizedBox(
      width: 520,
      height: 400,
      child: Column(
        children: [
          TextField(
            key: const ValueKey('batch.reference.search'),
            controller: _search,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Tìm mã hoặc tên'),
            onSubmitted: (_) => _load(),
            onChanged: (_) {
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 350), () => _load());
            },
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
              onPressed: () => _load(page: _page),
              child: const Text('Thử lại'),
            ),
          ],
          Expanded(
            child: ListView(
              children: [
                if (!_busy && _error == null && _items.isEmpty)
                  const ListTile(title: Text('Không có dữ liệu.')),
                ..._items.map(
                  (x) => ListTile(
                    key: ValueKey('batch.reference.${x.id}'),
                    title: Text(x.label),
                    onTap: () => Navigator.of(context).pop(x),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const ValueKey('batch.reference.previous'),
                onPressed: _busy || _page <= 1
                    ? null
                    : () => _load(page: _page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Trang ${_pages == 0 ? 0 : _page}/$_pages'),
              IconButton(
                key: const ValueKey('batch.reference.next'),
                onPressed: _busy || _page >= _pages
                    ? null
                    : () => _load(page: _page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Đóng'),
      ),
    ],
  );
}
