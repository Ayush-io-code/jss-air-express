// lib/screens/zip_import_screen.dart
//
// Flow:
//   1. User picks a .zip file
//   2. Each .xlsx inside is parsed — filename (without .xlsx) = party name
//   3. Preview: list of parties with bill counts, each with a name override field
//   4. Tap Import → calls importPartyWithBills() for each
//   5. Success summary

import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/theme.dart';
import '../utils/excel_importer.dart';
import '../widgets/common_widgets.dart';

class ZipImportScreen extends StatefulWidget {
  const ZipImportScreen({super.key});
  @override
  State<ZipImportScreen> createState() => _ZipImportScreenState();
}

// Holds parsed data for one Excel file inside the ZIP
class _ParsedParty {
  final String detectedName;   // from filename
  final TextEditingController nameCtrl;
  final List<ImportedBill> bills;
  bool include;

  _ParsedParty({
    required this.detectedName,
    required this.bills,
  })  : nameCtrl = TextEditingController(text: detectedName),
        include = true;

  void dispose() => nameCtrl.dispose();
}

class _ZipImportScreenState extends State<ZipImportScreen> {
  bool _picking = false;
  bool _importing = false;
  String? _fileName;
  String? _pickError;
  List<_ParsedParty> _parties = [];
  List<String> _warnings = [];

  @override
  void dispose() {
    for (final p in _parties) p.dispose();
    super.dispose();
  }

  Future<void> _pickZip() async {
    setState(() { _picking = true; _pickError = null; _parties = []; _warnings = []; });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) { setState(() => _picking = false); return; }
      final bytes = res.files.first.bytes;
      if (bytes == null) {
        setState(() { _picking = false; _pickError = 'Could not read ZIP file.'; });
        return;
      }
      _processZip(res.files.first.name, bytes);
    } catch (e) {
      setState(() { _picking = false; _pickError = 'Error opening file: $e'; });
    }
  }

  void _processZip(String name, Uint8List bytes) {
    final warnings = <String>[];
    final parsed = <_ParsedParty>[];

    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final fname = file.name.split('/').last; // handle folders inside zip
        if (!fname.toLowerCase().endsWith('.xlsx')) continue;
        if (fname.startsWith('~') || fname.startsWith('.')) continue; // temp files

        final partyName = fname.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '').trim();
        if (partyName.isEmpty) continue;

        try {
          final xlsxBytes = Uint8List.fromList(file.content as List<int>);
          final result = parseExcelFile(xlsxBytes);
          warnings.addAll(result.warnings.map((w) => '[$partyName] $w'));
          if (result.bills.isNotEmpty) {
            parsed.add(_ParsedParty(detectedName: partyName, bills: result.bills));
          } else {
            warnings.add('[$partyName] No bills found in this file, skipped.');
          }
        } catch (e) {
          warnings.add('[$partyName] Parse error: $e');
        }
      }
    } catch (e) {
      setState(() { _picking = false; _pickError = 'Invalid ZIP file: $e'; });
      return;
    }

    setState(() {
      _fileName = name;
      _parties = parsed;
      _warnings = warnings;
      _picking = false;
    });
  }

  int get _totalBills => _parties
      .where((p) => p.include)
      .fold(0, (s, p) => s + p.bills.length);

  Future<void> _doImport() async {
    setState(() => _importing = true);
    final app = context.read<AppProvider>();
    int totalImported = 0;
    int totalSkipped  = 0;

    for (final party in _parties) {
      if (!party.include) continue;
      final partyName = party.nameCtrl.text.trim();
      if (partyName.isEmpty) continue;

      final billList = party.bills.map((ib) => (
        billNo:   ib.bill.billNo,
        billDate: ib.bill.billDate,
        entries:  ib.bill.entries,
      )).toList();

      final imported = await app.importPartyWithBills(
        partyName: partyName,
        bills: billList,
      );
      totalImported += imported;
      totalSkipped  += billList.length - imported;
    }

    setState(() => _importing = false);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Import Complete'),
        content: Text(
          '$totalImported bill${totalImported == 1 ? '' : 's'} imported.'
          '${totalSkipped > 0 ? '\n$totalSkipped skipped (duplicate bill numbers).' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Import ZIP of Bills'),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _picking
            ? const Center(child: CircularProgressIndicator())
            : _importing
                ? const Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Importing…'),
                    ]))
                : _parties.isEmpty
                    ? _buildPicker()
                    : _buildPreview(),
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 32),
        const Icon(Icons.folder_zip, size: 72, color: kNavy),
        const SizedBox(height: 24),
        const Text('Import ZIP of Bills',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kNavy)),
        const SizedBox(height: 12),
        const Text(
          'Put all your Excel files in a single ZIP.\n'
          'Each file should be named after the party:\n'
          '"RJ Lumen.xlsx", "Southern Surgicals.xlsx" etc.\n\n'
          'Parties will be created automatically. You can rename them before importing.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54, height: 1.6),
        ),
        if (_pickError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(_pickError!, style: const TextStyle(color: Colors.red)),
          ),
        ],
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _pickZip,
          icon: const Icon(Icons.folder_zip),
          label: const Text('Choose ZIP File'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        color: kNavy,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_fileName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text('${_parties.length} part${_parties.length == 1 ? 'y' : 'ies'} detected · $_totalBills bills total',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),

      // Warnings
      if (_warnings.isNotEmpty)
        Container(
          color: Colors.orange.shade50,
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⚠️ Warnings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ..._warnings.map((w) => Text('• $w', style: const TextStyle(fontSize: 11))),
          ]),
        ),

      // Party list
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _parties.length,
          itemBuilder: (_, i) {
            final p = _parties[i];
            return _PartyImportCard(
              party: p,
              onToggle: (v) => setState(() => p.include = v),
              onNameChanged: (_) => setState(() {}),
            );
          },
        ),
      ),

      // Bottom bar
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _pickZip,
              child: const Text('Change ZIP'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _totalBills > 0 ? _doImport : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                _totalBills > 0
                    ? 'Import $_totalBills Bill${_totalBills == 1 ? '' : 's'}'
                    : 'Nothing to Import',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _PartyImportCard extends StatelessWidget {
  final _ParsedParty party;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onNameChanged;

  const _PartyImportCard({
    required this.party,
    required this.onToggle,
    required this.onNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    final billCount = party.bills.length;
    final entryCount = party.bills.fold(0, (s, b) => s + b.bill.entries.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: party.include ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: party.include ? const Color(0xFF1A3A5C) : Colors.grey.shade300,
          width: party.include ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row: checkbox + bill/entry counts
          Row(children: [
            Checkbox(
              value: party.include,
              activeColor: kNavy,
              onChanged: (v) => onToggle(v ?? true),
            ),
            Expanded(
              child: Text(
                party.detectedName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: party.include ? kNavy : Colors.grey,
                ),
              ),
            ),
            Text(
              '$billCount bill${billCount == 1 ? '' : 's'} · $entryCount entries',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ]),

          if (party.include) ...[
            const SizedBox(height: 8),
            // Editable party name
            TextField(
              controller: party.nameCtrl,
              onChanged: onNameChanged,
              decoration: InputDecoration(
                labelText: 'Party name (editable)',
                labelStyle: const TextStyle(fontSize: 12),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: kInputBg,
                helperText: party.nameCtrl.text.trim() != party.detectedName
                    ? 'Changed from "${party.detectedName}"'
                    : null,
                helperStyle: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
