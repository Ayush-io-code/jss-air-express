// lib/utils/helpers.dart
import 'package:intl/intl.dart';

String todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

String fmtINR(double n) {
  final fmt = NumberFormat('#,##,##0.##', 'en_IN');
  return '₹${fmt.format(n)}';
}

String fmtINR2(double n) {
  final fmt = NumberFormat('#,##,##0.00', 'en_IN');
  return '₹${fmt.format(n)}';
}

String fmtDate(String s) {
  if (s.isEmpty) return '';
  try {
    final d = DateTime.parse(s);
    return DateFormat('dd MMM yyyy').format(d);
  } catch (_) {
    return s;
  }
}

String monthLabel(String key) {
  final parts = key.split('-');
  if (parts.length < 2) return key;
  final y = int.tryParse(parts[0]) ?? 2024;
  final m = int.tryParse(parts[1]) ?? 1;
  return DateFormat('MMMM yyyy').format(DateTime(y, m, 1));
}

String monthOf(String d) {
  if (d.isEmpty) return todayStr().substring(0, 7);
  return d.substring(0, 7);
}
