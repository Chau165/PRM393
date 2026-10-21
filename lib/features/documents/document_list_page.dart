import 'package:flutter/material.dart';

import '../../domain/models/warehouse_app_data.dart';
import '../../domain/services/domain_exception.dart';
import '../../domain/services/warehouse_app_state.dart';
import '../../shared/formatters.dart';
import '../../shared/widgets/common.dart';
import 'document_editor_dialog.dart';

class DocumentListPage extends StatefulWidget {
  const DocumentListPage({
    super.key,
    required this.state,
    required this.user,
    required this.isReceipt,
  });

  final WarehouseAppState state;
  final AppUser user;
  final bool isReceipt;

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> {
  final _search = TextEditingController();
  int? _warehouseId;
  DocumentStatus? _status;
  String _query = '';

  bool get _isReceipt => widget.isReceipt;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Object> get _documents {
    final all = _isReceipt
        ? widget.state
              .visibleReceipts(widget.user, warehouseId: _warehouseId)
              .cast<Object>()
        : widget.state
              .visibleIssues(widget.user, warehouseId: _warehouseId)
              .cast<Object>();
    final query = _query.trim().toLowerCase();
    return all.where((document) {
      final number = document is ReceiptDocument
          ? document.documentNo
          : (document as IssueDocument).documentNo;
      final status = document is ReceiptDocument
          ? document.status
          : (document as IssueDocument).status;
      return (query.isEmpty || number.toLowerCase().contains(query)) &&
          (_status == null || status == _status);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final warehouses = widget.state.getAllowedWarehouses(widget.user);
        final docs = _documents;
        return SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                title: _isReceipt ? 'Phiếu nhập kho' : 'Phiếu xuất kho',
                subtitle: 'Lưu chứng từ ở trạng thái nháp, sau đó Post để ghi nhận nghiệp vụ.',
                action: FilledButton.icon(
                  onPressed: () => _openEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Tạo phiếu'),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: compact ? double.infinity : 300,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: const InputDecoration(
                        hintText: 'Tìm số phiếu...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: compact ? double.infinity : 245,
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      initialValue: _warehouseId,
                      decoration: const InputDecoration(
                        labelText: 'Lọc theo kho',
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
                    width: compact ? double.infinity : 190,
                    child: DropdownButtonFormField<DocumentStatus?>(
                      isExpanded: true,
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Trạng thái',
                      ),
                      items: const [
                        DropdownMenuItem<DocumentStatus?>(
                          value: null,
                          child: Text('Tất cả trạng thái'),
                        ),
                        DropdownMenuItem<DocumentStatus?>(
                          value: DocumentStatus.draft,
                          child: Text('Nháp'),
                        ),
                        DropdownMenuItem<DocumentStatus?>(
                          value: DocumentStatus.posted,
                          child: Text('Đã Post'),
                        ),
                      ],
                      onChanged: (value) => setState(() => _status = value),
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
                child: docs.isEmpty
                    ? const SizedBox(
                        height: 240,
                        child: EmptyState(title: 'Chưa có phiếu phù hợp'),
                      )
                    : compact
                    ? Column(
                        children: [
                          for (final document in docs)
                            _mobileDocument(document),
                        ],
                      )
                    : _desktopDocuments(docs),
              ),
              const SizedBox(height: 10),
              Text(
                '${docs.length} phiếu',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _desktopDocuments(List<Object> documents) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Số phiếu')),
          DataColumn(label: Text('Ngày')),
          DataColumn(label: Text('Kho')),
          DataColumn(label: Text('Trạng thái')),
          DataColumn(label: Text('Thao tác')),
        ],
        rows: [
          for (final document in documents)
            DataRow(
              cells: [
                DataCell(
                  Text(
                    _number(document),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(formatDate(_date(document)))),
                DataCell(Text(_warehouseName(document))),
                DataCell(
                  StatusBadge(
                    posted: _statusOf(document) == DocumentStatus.posted,
                  ),
                ),
                DataCell(_actions(document)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _mobileDocument(Object document) => Column(
    children: [
      ListTile(
        title: Text(
          _number(document),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_warehouseName(document)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(formatDate(_date(document))),
                  const SizedBox(width: 9),
                  StatusBadge(
                    posted: _statusOf(document) == DocumentStatus.posted,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: _actions(document),
      ),
      const Divider(height: 1, indent: 16, endIndent: 16),
    ],
  );

  Widget _actions(Object document) {
    final id = _id(document);
    final posted = _statusOf(document) == DocumentStatus.posted;
    return Wrap(
      spacing: 0,
      children: [
        IconButton(
          tooltip: posted ? 'Xem phiếu' : 'Sửa phiếu',
          onPressed: () => _openEditor(document),
          icon: Icon(
            posted ? Icons.visibility_outlined : Icons.edit_outlined,
            size: 19,
          ),
        ),
        if (!posted) ...[
          IconButton(
            tooltip: 'Post phiếu',
            onPressed: () => _post(id),
            icon: const Icon(Icons.check_circle_outline, size: 19),
          ),
          IconButton(
            tooltip: 'Xóa phiếu nháp',
            onPressed: () => _delete(id),
            icon: const Icon(Icons.delete_outline, size: 19),
          ),
        ],
      ],
    );
  }

  Future<void> _openEditor([Object? existing]) async {
    final receipt = existing is ReceiptDocument ? existing : null;
    final issue = existing is IssueDocument ? existing : null;
    final result = await showDialog<DocumentDraftResult>(
      context: context,
      builder: (_) => DocumentEditorDialog(
        state: widget.state,
        user: widget.user,
        isReceipt: _isReceipt,
        receipt: receipt,
        issue: issue,
      ),
    );
    if (result == null || !mounted) return;

    try {
      if (_isReceipt) {
        final saved = await widget.state.saveReceipt(
          widget.user,
          (receipt ??
                  ReceiptDocument(
                    id: 0,
                    documentNo: result.documentNo,
                    warehouseId: result.warehouseId,
                    supplierId: result.supplierId!,
                    documentDate: result.documentDate,
                  ))
              .copyWith(
                documentNo: result.documentNo,
                warehouseId: result.warehouseId,
                supplierId: result.supplierId,
                documentDate: result.documentDate,
                note: result.note,
              ),
          [
            for (final line in result.details)
              ReceiptDetail(
                id: line.id,
                receiptId: receipt?.id ?? 0,
                productId: line.productId,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
              ),
          ],
        );
        if (result.postAfterSave) {
          await widget.state.postReceipt(widget.user, saved.id);
        }
      } else {
        final saved = await widget.state.saveIssue(
          widget.user,
          (issue ??
                  IssueDocument(
                    id: 0,
                    documentNo: result.documentNo,
                    warehouseId: result.warehouseId,
                    documentDate: result.documentDate,
                  ))
              .copyWith(
                documentNo: result.documentNo,
                warehouseId: result.warehouseId,
                documentDate: result.documentDate,
                note: result.note,
              ),
          [
            for (final line in result.details)
              IssueDetail(
                id: line.id,
                issueId: issue?.id ?? 0,
                productId: line.productId,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
              ),
          ],
        );
        if (result.postAfterSave) {
          await widget.state.postIssue(widget.user, saved.id);
        }
      }
      if (mounted) {
        showAppMessage(
          context,
          result.postAfterSave ? 'Phiếu đã được Post.' : 'Đã lưu phiếu nháp.',
        );
      }
    } catch (error) {
      if (mounted) showAppMessage(context, _message(error), isError: true);
    }
  }

  Future<void> _post(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận Post phiếu'),
        content: const Text(
          'Phiếu sau khi Post sẽ không thể chỉnh sửa. Bạn có chắc chắn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post phiếu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (_isReceipt) {
        await widget.state.postReceipt(widget.user, id);
      } else {
        await widget.state.postIssue(widget.user, id);
      }
      if (mounted) showAppMessage(context, 'Phiếu đã được Post.');
    } catch (error) {
      if (mounted) showAppMessage(context, _message(error), isError: true);
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa phiếu nháp?'),
        content: const Text('Phiếu nháp và các chi tiết của phiếu sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa phiếu'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (_isReceipt) {
        await widget.state.deleteReceipt(widget.user, id);
      } else {
        await widget.state.deleteIssue(widget.user, id);
      }
      if (mounted) showAppMessage(context, 'Đã xóa phiếu nháp.');
    } catch (error) {
      if (mounted) showAppMessage(context, _message(error), isError: true);
    }
  }

  String _number(Object doc) => doc is ReceiptDocument
      ? doc.documentNo
      : (doc as IssueDocument).documentNo;
  int _id(Object doc) =>
      doc is ReceiptDocument ? doc.id : (doc as IssueDocument).id;
  DateTime _date(Object doc) => doc is ReceiptDocument
      ? doc.documentDate
      : (doc as IssueDocument).documentDate;
  DocumentStatus _statusOf(Object doc) =>
      doc is ReceiptDocument ? doc.status : (doc as IssueDocument).status;

  String _warehouseName(Object doc) {
    final id = doc is ReceiptDocument
        ? doc.warehouseId
        : (doc as IssueDocument).warehouseId;
    for (final warehouse in widget.state.data.warehouses) {
      if (warehouse.id == id) return warehouse.name;
    }
    return 'Kho không tồn tại';
  }

  String _message(Object error) => error is DomainException
      ? error.message
      : 'Không thể xử lý phiếu. Vui lòng thử lại.';
}
