import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'data/catalog_repository.dart';
import 'state/catalog_controller.dart';

class ManufacturerPicker extends StatefulWidget {
  const ManufacturerPicker({super.key, required this.api});
  final ApiClient api;
  @override
  State<ManufacturerPicker> createState() => _ManufacturerPickerState();
}

class _ManufacturerPickerState extends State<ManufacturerPicker> {
  late final _controller = CatalogController(
    CatalogRepository(widget.api, CatalogResource.organizations),
  );
  final _search = TextEditingController();
  Timer? _debounce;
  bool _selecting = false;
  String? _selectionError;
  @override
  void initState() {
    super.initState();
    _controller.load(sort: 'name', filters: {'kind': 'Manufacturer'});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _find(String value) {
    _debounce?.cancel();
    _controller.load(page: 1, search: value);
  }

  Future<void> _select(CatalogItem item) async {
    if (_selecting) return;
    setState(() {
      _selecting = true;
      _selectionError = null;
    });
    try {
      final latest = await _controller.repository.get(item.id);
      if (!mounted) return;
      if (latest.kind != 'Manufacturer') {
        setState(
          () => _selectionError = 'Đối tác này không còn là nhà sản xuất.',
        );
        return;
      }
      Navigator.of(context).pop(latest);
    } on ApiException catch (e) {
      if (mounted) setState(() => _selectionError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _selectionError = 'Không thể chọn nhà sản xuất.');
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chọn nhà sản xuất'),
    content: SizedBox(
      width: 520,
      height: 420,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final c = _controller;
          return Column(
            children: [
              TextField(
                key: const ValueKey('manufacturer.search'),
                controller: _search,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tìm mã hoặc tên',
                  counterText: '',
                ),
                onSubmitted: _find,
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 350),
                    () => _find(value),
                  );
                },
              ),
              const SizedBox(height: 12),
              if (c.loading || _selecting) const LinearProgressIndicator(),
              if (_selectionError != null)
                Text(
                  _selectionError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: c.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.error!),
                            TextButton(
                              onPressed: () => c.load(),
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : !c.loading && c.items.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có nhà sản xuất phù hợp. Bạn có thể tạo tại danh mục Đối tác.',
                        ),
                      )
                    : ListView(
                        children: [
                          for (final item in c.items)
                            ListTile(
                              key: ValueKey('manufacturer.select.${item.id}'),
                              title: Text(item.name),
                              subtitle: Text('${item.code} · ${item.country}'),
                              enabled: !_selecting,
                              onTap: () => _select(item),
                            ),
                        ],
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Trang ${c.totalPages == 0 ? 0 : c.page}/${c.totalPages}',
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('manufacturer.previous'),
                        tooltip: 'Trang trước',
                        onPressed: c.loading || _selecting || c.page <= 1
                            ? null
                            : () => c.load(page: c.page - 1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      IconButton(
                        key: const ValueKey('manufacturer.next'),
                        tooltip: 'Trang sau',
                        onPressed:
                            c.loading || _selecting || c.page >= c.totalPages
                            ? null
                            : () => c.load(page: c.page + 1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
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
