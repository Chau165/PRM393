String formatQuantity(num value) {
  final rounded = value.toDouble() == value.toDouble().roundToDouble();
  final raw = value.toStringAsFixed(rounded ? 0 : 2);
  final pieces = raw.split('.');
  final whole = pieces.first;
  final grouped = whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  if (pieces.length == 1) return grouped;
  final decimals = pieces.last.replaceFirst(RegExp(r'0+$'), '');
  return decimals.isEmpty ? grouped : '$grouped,$decimals';
}

String formatCurrency(num value) => '${formatQuantity(value)} ₫';

String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
