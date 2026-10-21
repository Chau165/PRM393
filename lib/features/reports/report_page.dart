import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _search = TextEditingController();
  late DateTime _fromDate;
  late DateTime _toDate;
  int? _warehouseId;
  String _query = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month, now.day);
  }

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
        final warehouses = widget.state.getAllowedWarehouses(widget.user);
        final invalidRange = _fromDate.isAfter(_toDate);
        final rows = invalidRange
            ? const <InventoryPeriodReport>[]
            : widget.state.periodInventoryReport(
                widget.user,
                fromDate: _fromDate,
                toDate: _toDate,
                warehouseId: _warehouseId,
                search: _query,
              );
        final totals = _ReportTotals.fromRows(rows);
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                title: 'Báo cáo Xuất - Nhập - Tồn',
                subtitle:
                    'Báo cáo lịch sử chỉ tính các phiếu đã Post trong kỳ.',
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _dateFilter(
                    context,
                    'Từ ngày',
                    _fromDate,
                    (value) => setState(() => _fromDate = value),
                  ),
                  _dateFilter(
                    context,
                    'Đến ngày',
                    _toDate,
                    (value) => setState(() => _toDate = value),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 260,
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Kho (không bắt buộc)',
                      ),
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
                    width: compact ? double.infinity : 300,
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
              if (invalidRange) ...[
                const SizedBox(height: 12),
                const Text(
                  'Ngày bắt đầu phải nhỏ hơn hoặc bằng ngày kết thúc.',
                  style: TextStyle(color: Color(0xFFB42318)),
                ),
              ],
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
                        height: 230,
                        child: EmptyState(title: 'Không có phát sinh trong kỳ'),
                      )
                    : compact
                    ? Column(
                        children: [for (final row in rows) _mobileRow(row)],
                      )
                    : _desktopTable(rows),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('Tổng đầu kỳ: ${formatQuantity(totals.opening)}'),
                      Text('Tổng nhập: ${formatQuantity(totals.received)}'),
                      Text('Tổng xuất: ${formatQuantity(totals.issued)}'),
                      Text(
                        'Tổng cuối kỳ: ${formatQuantity(totals.closing)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _dateFilter(
    BuildContext context,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) {
    return SizedBox(
      width: 170,
      child: OutlinedButton.icon(
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (selected != null) onChanged(selected);
        },
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            Text(
              formatDate(value),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          side: const BorderSide(color: Color(0xFFDCE3EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _desktopTable(List<InventoryPeriodReport> rows) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Kho')),
            DataColumn(label: Text('Mã SP')),
            DataColumn(label: Text('Tên sản phẩm')),
            DataColumn(label: Text('ĐVT')),
            DataColumn(label: Text('SL đầu kỳ'), numeric: true),
            DataColumn(label: Text('SL nhập'), numeric: true),
            DataColumn(label: Text('SL xuất'), numeric: true),
            DataColumn(label: Text('SL cuối kỳ'), numeric: true),
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
                  DataCell(Text(formatQuantity(row.opening))),
                  DataCell(Text(formatQuantity(row.received))),
                  DataCell(Text(formatQuantity(row.issued))),
                  DataCell(
                    Text(
                      formatQuantity(row.closing),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
          ],
        ),
      );

  Widget _mobileRow(InventoryPeriodReport row) => Column(
    children: [
      ListTile(
        title: Text(row.productName),
        subtitle: Text(
          '${row.productCode} · ${row.warehouseName} · ${row.unitName}',
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Wrap(
          spacing: 15,
          runSpacing: 8,
          children: [
            _reportValue('Đầu kỳ', row.opening),
            _reportValue('Nhập', row.received),
            _reportValue('Xuất', row.issued),
            _reportValue('Cuối kỳ', row.closing, bold: true),
          ],
        ),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );

  Widget _reportValue(String label, double value, {bool bold = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            formatQuantity(value),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );
}

class _ReportTotals {
  const _ReportTotals(this.opening, this.received, this.issued, this.closing);

  final double opening;
  final double received;
  final double issued;
  final double closing;

  factory _ReportTotals.fromRows(List<InventoryPeriodReport> rows) =>
      _ReportTotals(
        rows.fold(0, (sum, row) => sum + row.opening),
        rows.fold(0, (sum, row) => sum + row.received),
        rows.fold(0, (sum, row) => sum + row.issued),
        rows.fold(0, (sum, row) => sum + row.closing),
      );
}
