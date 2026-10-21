import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _search = TextEditingController();
  int? _warehouseId;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final rows = widget.state.currentInventory(
          widget.user,
          warehouseId: _warehouseId,
          search: _query,
        );
        final warehouses = widget.state.getAllowedWarehouses(widget.user);
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                title: 'Tồn kho hiện tại',
                subtitle: 'Tồn thực tế được tính từ phiếu đã Post; phiếu xuất nháp tạo lượng hàng đang giữ.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 300,
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(labelText: 'Kho'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tất cả kho được phép'),
                        ),
                        for (final warehouse in warehouses)
                          DropdownMenuItem<int?>(
                            value: warehouse.id,
                            child: Text(warehouse.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _warehouseId = value),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 360,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Tìm mã hoặc tên sản phẩm...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                child: rows.isEmpty
                    ? const SizedBox(
                        height: 240,
                        child: EmptyState(title: 'Không có dữ liệu tồn kho'),
                      )
                    : compact
                    ? Column(
                        children: [for (final row in rows) _mobileRow(row)],
                      )
                    : _desktopTable(rows),
              ),
              const SizedBox(height: 10),
              Text(
                '${rows.length} dòng tồn kho',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _desktopTable(List<InventoryItem> rows) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Kho')),
        DataColumn(label: Text('Mã sản phẩm')),
        DataColumn(label: Text('Tên sản phẩm')),
        DataColumn(label: Text('Đơn vị tính')),
        DataColumn(label: Text('Tồn thực tế'), numeric: true),
        DataColumn(label: Text('Đang giữ'), numeric: true),
        DataColumn(label: Text('Khả dụng'), numeric: true),
      ],
      rows: [
        for (final row in rows)
          DataRow(
            cells: [
              DataCell(Text(row.warehouseName)),
              DataCell(
                Text(
                  row.productCode,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(Text(row.productName)),
              DataCell(Text(row.unitName)),
              DataCell(Text(formatQuantity(row.onHand))),
              DataCell(Text(formatQuantity(row.reserved))),
              DataCell(_availableValue(row)),
            ],
          ),
      ],
    ),
  );

  Widget _mobileRow(InventoryItem row) => Column(
    children: [
      ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                row.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (row.available <= 5)
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFC28316),
                size: 19,
              ),
          ],
        ),
        subtitle: Text(
          '${row.productCode} · ${row.warehouseName} · ${row.unitName}',
        ),
        isThreeLine: true,
        trailing: Text(
          formatQuantity(row.available),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: [
            Expanded(child: _quantityLabel('Tồn thực tế', row.onHand)),
            Expanded(child: _quantityLabel('Đang giữ', row.reserved)),
            Expanded(child: _quantityLabel('Khả dụng', row.available)),
          ],
        ),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );

  Widget _quantityLabel(String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 3),
      Text(
        formatQuantity(value),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ],
  );

  Widget _availableValue(InventoryItem row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (row.available <= 5) ...[
        const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFC28316),
          size: 17,
        ),
        const SizedBox(width: 5),
      ],
      Text(
        formatQuantity(row.available),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );
}
