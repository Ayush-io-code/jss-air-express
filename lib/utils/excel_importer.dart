// lib/utils/excel_importer.dart
//
// Reads Excel files that were exported by this app (one sheet per bill,
// sheet name = bill number, e.g. "81").
//
// Expected column layout (matches bill_exporter row order):
//   A: S.No  B: Date  C: AWB No  D: KG  E: Mode  F: Destination
//   G: Client Name  H: Amount
//
// The importer is intentionally lenient — extra columns, blank rows, and
// totals/summary rows are silently skipped.  Only rows where column C
// (AWB) is non-empty are treated as entry rows.

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../models/bill.dart';
import '../models/entry.dart';
import '../models/party.dart';

const _uuid = Uuid();

class ImportedBill {
  final Bill bill;
  final String partyName;
  ImportedBill({required this.bill, required this.partyName});
}

class ImportResult {
  final List<ImportedBill> bills;
  final List<String> warnings;
  const ImportResult({required this.bills, required this.warnings});
}

ImportResult parseExcelFile(Uint8List bytes) {
  final excel = Excel.decodeBytes(bytes);
  final bills = <ImportedBill>[];
  final warnings = <String>[];

  for (final sheetName in excel.tables.keys) {
    final sheet = excel.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) continue;

    try {
      final result = _parseSheet(sheetName, sheet);
      if (result != null) {
        bills.add(result);
      } else {
        warnings.add('Sheet "$sheetName": no entry rows found, skipped.');
      }
    } catch (e) {
      warnings.add('Sheet "$sheetName": parse error — $e');
    }
  }

  return ImportResult(bills: bills, warnings: warnings);
}

ImportedBill? _parseSheet(String sheetName, Sheet sheet) {
  String partyName = '';
  String billNo = sheetName.trim();
  String billDate = '';
  int headerRowIdx = -1;

  final rows = sheet.rows;

  for (int i = 0; i < rows.length && i < 15; i++) {
    final row = rows[i];
    final firstCell = _str(row.isNotEmpty ? row[0] : null).toLowerCase();
    final secondCell = _str(row.length > 1 ? row[1] : null);

    if (firstCell.contains('party')) partyName = secondCell;
    if (firstCell.contains('bill no')) billNo = secondCell.replaceAll(RegExp(r'^\d{4}/'), '').trim();
    if (firstCell.contains('bill date')) billDate = _parseDate(secondCell);

    final rowText = row.map((c) => _str(c).toLowerCase()).join(' ');
    if (rowText.contains('awb')) {
      headerRowIdx = i;
      break;
    }
  }

  if (billNo.isEmpty) billNo = sheetName.trim();

  final entries = <Entry>[];
  final startRow = headerRowIdx >= 0 ? headerRowIdx + 1 : 1;

  for (int i = startRow; i < rows.length; i++) {
    final row = rows[i];
    if (row.length < 3) continue;

    final awb = _str(row.length > 2 ? row[2] : null).trim();
    if (awb.isEmpty) continue;

    if (awb.toLowerCase().contains('total') ||
        awb.toLowerCase().contains('gross') ||
        awb.toLowerCase().contains('net')) continue;

    final date        = _parseDate(_str(row.length > 1 ? row[1] : null));
    final kg          = _str(row.length > 3 ? row[3] : null).trim();
    final modeRaw     = _str(row.length > 4 ? row[4] : null).trim().toUpperCase();
    final mode        = Entry.modes.contains(modeRaw) ? modeRaw : 'AIR';
    final destination = _str(row.length > 5 ? row[5] : null).trim();
    final clientName  = _str(row.length > 6 ? row[6] : null).trim();
    final priceRaw    = _str(row.length > 7 ? row[7] : null).trim();
    final price       = _cleanPrice(priceRaw);

    entries.add(Entry(
      id:          _uuid.v4(),
      date:        date,
      awb:         awb,
      kg:          kg,
      mode:        mode,
      destination: destination,
      clientName:  clientName,
      price:       price,
      updatedAt:   DateTime.now().millisecondsSinceEpoch,
    ));
  }

  if (entries.isEmpty) return null;

  final bill = Bill(
    id:        _uuid.v4(),
    partyId:   '',
    billNo:    billNo,
    billDate:  billDate,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    entries:   entries,
  );

  return ImportedBill(bill: bill, partyName: partyName);
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Convert a Data cell to plain String using excel 4.x sealed CellValue API.
String _str(Data? cell) {
  if (cell == null || cell.value == null) return '';
  final v = cell.value;
  if (v is TextCellValue)     return v.value.toString();
  if (v is IntCellValue)      return v.value.toString();
  if (v is DoubleCellValue) {
    final d = v.value;
    return d % 1 == 0 ? d.toInt().toString() : d.toString();
  }
  if (v is BoolCellValue)     return v.value.toString();
  if (v is DateCellValue) {
    final dt = v.asDateTimeUtc();
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
  }
  if (v is DateTimeCellValue) {
    final dt = v.asDateTimeUtc();
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
  }
  if (v is TimeCellValue)    return v.toString();
  if (v is FormulaCellValue) return v.toString();
  return '';
}

String _parseDate(String raw) {
  if (raw.isEmpty) return '';
  final s = raw.trim();

  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return s.substring(0, 10);

  final slash = RegExp(r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$');
  final m = slash.firstMatch(s);
  if (m != null) {
    final d  = m.group(1)!.padLeft(2, '0');
    final mo = m.group(2)!.padLeft(2, '0');
    final y  = m.group(3)!;
    return '$y-$mo-$d';
  }

  const months = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
    'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
    'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12',
  };
  final wordy = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})$');
  final wm = wordy.firstMatch(s);
  if (wm != null) {
    final d  = wm.group(1)!.padLeft(2, '0');
    final mo = months[wm.group(2)!.toLowerCase()] ?? '01';
    final y  = wm.group(3)!;
    return '$y-$mo-$d';
  }

  return '';
}

String _cleanPrice(String raw) {
  if (raw.isEmpty) return '';
  final cleaned = raw.replaceAll(RegExp(r'[₹,\s]'), '');
  final num = double.tryParse(cleaned);
  if (num == null) return '';
  return num % 1 == 0 ? num.toInt().toString() : num.toString();
}

Party? matchParty(List<Party> parties, String name) {
  if (name.isEmpty) return null;
  final lower = name.trim().toLowerCase();
  try {
    return parties.firstWhere((p) => p.name.trim().toLowerCase() == lower);
  } catch (_) {
    return null;
  }
}
