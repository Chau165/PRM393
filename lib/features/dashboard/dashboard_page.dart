import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state, required this.user});

  final WarehouseAppState state;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final warehouses = state.getAllowedWarehouses(user);
    final receipts = state.visibleReceipts(user);
    final issues = state.visibleIssues(user);
    final inventory = state.currentInventory(user);
    final metrics = <_MetricData>[
      _MetricData(
        'Kho được phân quyền',
        warehouses.length.toString(),
        Icons.warehouse_outlined,
        const Color(0xFF2873C8),
      ),
      _MetricData(
        'Sản phẩm',
        state.data.products.length.toString(),
        Icons.inventory_2_outlined,
        const Color(0xFF6B58C8),
      ),
      _MetricData(
        'Phiếu nhập nháp',
        receipts
            .where((doc) => doc.status == DocumentStatus.draft)
            .length
            .toString(),
        Icons.move_to_inbox_outlined,
        const Color(0xFFC28316),
      ),
      _MetricData(
        'Phiếu nhập đã Post',
        receipts
            .where((doc) => doc.status == DocumentStatus.posted)
            .length
            .toString(),
        Icons.inventory_outlined,
        const Color(0xFF14846A),
      ),
      _MetricData(
        'Phiếu xuất nháp',
        issues
            .where((doc) => doc.status == DocumentStatus.draft)
            .length
            .toString(),
        Icons.pending_actions_outlined,
        const Color(0xFFC28316),
      ),
      _MetricData(
        'Phiếu xuất đã Post',
        issues
            .where((doc) => doc.status == DocumentStatus.posted)
            .length
            .toString(),
        Icons.outbox_outlined,
        const Color(0xFF14846A),
      ),
      _MetricData(
        'Tồn thực tế',
        formatQuantity(
          inventory.fold<double>(0, (sum, row) => sum + row.onHand),
        ),
        Icons.inventory_2_rounded,
        const Color(0xFF2873C8),
      ),
      _MetricData(
        'Đang giữ',
        formatQuantity(
          inventory.fold<double>(0, (sum, row) => sum + row.reserved),
        ),
        Icons.lock_clock_outlined,
        const Color(0xFFC28316),
      ),
      _MetricData(
        'Khả dụng',
        formatQuantity(
          inventory.fold<double>(0, (sum, row) => sum + row.available),
        ),
        Icons.check_circle_outline,
        const Color(0xFF14846A),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1250
            ? 3
            : constraints.maxWidth >= 690
            ? 2
            : 1;
        final spacing = 14.0;
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: 'Xin chào, ${user.fullName.split(' ').first}',
                subtitle: 'Tổng quan hoạt động kho của bạn.',
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B7A72), Color(0xFF145B76)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bức tranh tồn kho',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${formatQuantity(inventory.fold<double>(0, (sum, row) => sum + row.available))} đơn vị hàng đang khả dụng',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Số liệu được tính trực tiếp từ các phiếu đã Post và phiếu xuất nháp.',
                            style: TextStyle(color: Color(0xFFD6EFEB)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.query_stats_rounded,
                      color: Colors.white70,
                      size: 42,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final metric in metrics)
                    SizedBox(
                      width: width,
                      child: _MetricCard(metric: metric),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE7ECF2)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kho trong phạm vi của bạn',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      for (final warehouse in warehouses)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.warehouse_outlined),
                          ),
                          title: Text(warehouse.name),
                          subtitle: Text(
                            warehouse.note.isEmpty
                                ? 'Được phép truy cập'
                                : warehouse.note,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      if (warehouses.isEmpty)
                        const EmptyState(title: 'Chưa được phân quyền kho'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MetricData metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE7ECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: metric.color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(metric.icon, color: metric.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
