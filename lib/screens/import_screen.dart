// lib/screens/import_screen.dart
//
// Full flow:
//   1. User taps "Import from Excel" → picks a .xlsx file
//   2. Parser runs → shows a list of detected bills with entry counts
//   3. Each bill has a party dropdown (auto-matched if name found)
//   4. Bills that duplicate an existing bill number are flagged
//   5. User taps "Import X bills" → provider saves them → success screen

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/party.dart';
import '../utils/theme.dart';
import '../utils/excel_importer.dart';
import '../utils/helpers.dart';

// We use file_picker only if available; otherwise fall back to a helpful message.
// To keep this file self-contained we import conditionally via a try/catch at runtime.
import 'package:file_picker/file_picker.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _picking = false;
  bool _importing = false;
  ImportResult? _result;
  String? _fileName;
  String? _pickError;

  // Per-bill state: which party is selected
  final Map<String, String?> _selectedPartyId = {}; // bill.id → partyId or null

  Future<void> _pickFile() async {
    setState(() { _picking = true; _pickError = null; _result = null; });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = res.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() { _picking = false; _pickError = 'Could not read file bytes.'; });
        return;
      }
      try {
        _processFile(file.name, bytes);
      } catch (e) {
        setState(() { _picking = false; _pickError = 'Failed to parse Excel file: $e'; });
      }
    } catch (e) {
      setState(() { _picking = false; _pickError = 'Failed to open file: $e'; });
    }
  }

  void _processFile(String name, Uint8List bytes) {
    final app = context.read<AppProvider>();
    final parties = app.parties;

    final result = parseExcelFile(bytes);

    // Auto-match parties and detect duplicates
    for (final ib in result.bills) {
      final matched = matchParty(parties, ib.partyName);
      _selectedPartyId[ib.bill.id] = matched?.id;
    }

    setState(() {
      _result = result;
      _fileName = name;
      _picking = false;
    });
  }

  bool _isDupe(String billNo) {
    // Check across every party — bill numbers in this app are unique per-party,
    // but during import we don't know the partyId until the user picks one, so
    // we check against the partyId the user has currently selected for this bill.
    // If no party is selected yet we can't confirm a duplicate, so return false.
    return false; // duplicate check is done per-party at save time in importBill()
  }

  bool _isDupeForParty(String partyId, String billNo) {
    final app = context.read<AppProvider>();
    return app.isDupeBillNo(partyId, billNo);
  }

  int get _importableCount {
    if (_result == null) return 0;
    return _result!.bills.where((ib) {
      final partyId = _selectedPartyId[ib.bill.id];
      final hasParty = partyId != null;
      final notDupe  = partyId == null || !_isDupeForParty(partyId, ib.bill.billNo);
      return hasParty && notDupe;
    }).length;
  }

  Future<void> _doImport() async {
    if (_result == null) return;
    setState(() => _importing = true);
    final app = context.read<AppProvider>();
    int imported = 0;

    for (final ib in _result!.bills) {
      final partyId = _selectedPartyId[ib.bill.id];
      if (partyId == null) continue;
      if (_isDupeForParty(partyId, ib.bill.billNo)) continue;

      final bill = ib.bill;
      // Assign the resolved partyId
      await app.importBill(
        partyId:  partyId,
        billNo:   bill.billNo,
        billDate: bill.billDate,
        entries:  bill.entries,
      );
      imported++;
    }

    setState(() => _importing = false);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Import Complete'),
        content: Text('$imported bill${imported == 1 ? '' : 's'} imported successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);  // close dialog
              Navigator.pop(context);  // go back to home
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final parties = app.parties;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Import from Excel'),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _picking
            ? const Center(child: CircularProgressIndicator())
            : _importing
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Importing bills…'),
                      ],
                    ),
                  )
                : _result == null
                    ? _buildPickerPage()
                    : _buildPreviewPage(parties),
      ),
    );
  }

  // ── Step 1: Pick file ─────────────────────────────────────────────────────

  Widget _buildPickerPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.upload_file, size: 72, color: kNavy),
          const SizedBox(height: 24),
          const Text(
            'Import Old Bills',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kNavy),
          ),
          const SizedBox(height: 12),
          const Text(
            'Pick an Excel (.xlsx) file that was previously exported from this app. '
            'Each sheet should represent one bill — the app will detect entries '
            'automatically and let you assign parties before saving.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, height: 1.5),
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
            onPressed: _pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose Excel File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tip: Export your old bills as Excel first, then import them here '
            'to preserve all your historical data across financial years.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step 2: Preview detected bills ────────────────────────────────────────

  Widget _buildPreviewPage(List<Party> parties) {
    final result = _result!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header bar
        Container(
          color: kNavy,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fileName ?? 'Excel File',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              Text(
                '${result.bills.length} bill${result.bills.length == 1 ? '' : 's'} detected',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        // Warnings
        if (result.warnings.isNotEmpty)
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚠️ Warnings:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ...result.warnings.map((w) => Text('• $w', style: const TextStyle(fontSize: 11))),
              ],
            ),
          ),

        // Bill list
        Expanded(
          child: result.bills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inbox, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No bills found in this file.'),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _pickFile, child: const Text('Try another file')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: result.bills.length,
                  itemBuilder: (_, i) => _BillImportCard(
                    ib: result.bills[i],
                    parties: parties,
                    selectedPartyId: _selectedPartyId[result.bills[i].bill.id],
                    isDupe: _selectedPartyId[result.bills[i].bill.id] != null &&
                        _isDupeForParty(
                          _selectedPartyId[result.bills[i].bill.id]!,
                          result.bills[i].bill.billNo,
                        ),
                    onPartyChanged: (pid) => setState(
                        () => _selectedPartyId[result.bills[i].bill.id] = pid),
                  ),
                ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_importableCount < result.bills.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${result.bills.length - _importableCount} bill${result.bills.length - _importableCount == 1 ? '' : 's'} skipped '
                    '(duplicate bill number or no party assigned)',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                    textAlign: TextAlign.center,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _pickFile,
                      child: const Text('Change File'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _importableCount > 0 ? _doImport : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        _importableCount > 0
                            ? 'Import $_importableCount Bill${_importableCount == 1 ? '' : 's'}'
                            : 'Nothing to Import',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Per-bill card ─────────────────────────────────────────────────────────────

class _BillImportCard extends StatelessWidget {
  final ImportedBill ib;
  final List<Party> parties;
  final String? selectedPartyId;
  final bool isDupe;
  final ValueChanged<String?> onPartyChanged;

  const _BillImportCard({
    required this.ib,
    required this.parties,
    required this.selectedPartyId,
    required this.isDupe,
    required this.onPartyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bill = ib.bill;
    final entryCount = bill.entries.length;
    final hasParty = selectedPartyId != null;

    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.white;
    String statusLabel = '';

    if (isDupe) {
      borderColor = Colors.red.shade300;
      bgColor = Colors.red.shade50;
      statusLabel = 'Duplicate bill number — will be skipped';
    } else if (!hasParty) {
      borderColor = Colors.orange.shade300;
      bgColor = Colors.orange.shade50;
      statusLabel = 'Assign a party to import this bill';
    } else {
      borderColor = Colors.green.shade300;
      bgColor = Colors.green.shade50;
      statusLabel = 'Ready to import';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kNavy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Bill #${bill.billNo}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                if (bill.billDate.isNotEmpty)
                  Text(fmtDate(bill.billDate), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const Spacer(),
                Text(
                  '$entryCount entr${entryCount == 1 ? 'y' : 'ies'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Party selector
            DropdownButtonFormField<String>(
              value: selectedPartyId,
              decoration: InputDecoration(
                labelText: 'Assign to Party',
                labelStyle: const TextStyle(fontSize: 13),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                hintText: ib.partyName.isNotEmpty ? 'Detected: "${ib.partyName}"' : 'Select party',
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('— none —')),
                ...parties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
              ],
              onChanged: isDupe ? null : onPartyChanged,
            ),

            const SizedBox(height: 6),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                color: isDupe ? Colors.red : (!hasParty ? Colors.orange.shade800 : Colors.green.shade800),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
