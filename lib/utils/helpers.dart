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

// Rounds to nearest whole rupee — used in PDF/Excel exports
String fmtINRRounded(double n) {
  final rounded = n.round();
  final fmt = NumberFormat('#,##,##0', 'en_IN');
  return '₹${fmt.format(rounded)}';
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

// ── Amount in words ──────────────────────────────────────────────────────────

String amountInWords(double amount) {
  final rupees = amount.round();
  if (rupees == 0) return 'Zero Rupees Only';
  return 'Rupees ${_convertToWords(rupees)} Only';
}

const _ones = [
  '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
  'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
  'Seventeen', 'Eighteen', 'Nineteen'
];

const _tens = [
  '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
  'Sixty', 'Seventy', 'Eighty', 'Ninety'
];

String _convertToWords(int n) {
  if (n == 0) return '';
  if (n < 20) return _ones[n];
  if (n < 100) {
    return _tens[n ~/ 10] + (n % 10 != 0 ? ' ${_ones[n % 10]}' : '');
  }
  if (n < 1000) {
    return '${_ones[n ~/ 100]} Hundred'
        '${n % 100 != 0 ? ' ${_convertToWords(n % 100)}' : ''}';
  }
  if (n < 100000) {
    return '${_convertToWords(n ~/ 1000)} Thousand'
        '${n % 1000 != 0 ? ' ${_convertToWords(n % 1000)}' : ''}';
  }
  if (n < 10000000) {
    return '${_convertToWords(n ~/ 100000)} Lakh'
        '${n % 100000 != 0 ? ' ${_convertToWords(n % 100000)}' : ''}';
  }
  return '${_convertToWords(n ~/ 10000000)} Crore'
      '${n % 10000000 != 0 ? ' ${_convertToWords(n % 10000000)}' : ''}';
}

// ── Financial Year helpers ───────────────────────────────────────────────────
// Indian FY: April 1 → March 31.
// FY 2025-26 is represented as "2026" (the ending year).
// e.g. April 2025–March 2026 → FY "2026"

int currentFY() {
  final now = DateTime.now();
  return now.month >= 4 ? now.year + 1 : now.year;
}

// Returns "YYYY" label for a given date string (yyyy-MM-dd).
int fyOfDate(String dateStr) {
  if (dateStr.isEmpty) return currentFY();
  try {
    final d = DateTime.parse(dateStr);
    return d.month >= 4 ? d.year + 1 : d.year;
  } catch (_) {
    return currentFY();
  }
}
