// lib/screens/party_manage_screen.dart
//
// Three tabs:
//   • Merge  — pick source party → merge into target → source disappears
//   • Move Bill — pick a bill → pick destination party → move it
//   • Delete — pick a party → confirm → party + all bills deleted

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/party.dart';
import '../models/bill.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class PartyManageScreen extends StatelessWidget {
  const PartyManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          title: const Text('Manage Parties'),
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.merge, size: 18), text: 'Merge'),
              Tab(icon: Icon(Icons.drive_file_move, size: 18), text: 'Move Bill'),
              Tab(icon: Icon(Icons.delete_outline, size: 18), text: 'Delete'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _MergeTab(),
          _MoveBillTab(),
          _DeleteTab(),
        ]),
      ),
    );
  }
}

// ── MERGE TAB ────────────────────────────────────────────────────────────────

class _MergeTab extends StatefulWidget {
  const _MergeTab();
  @override
  State<_MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<_MergeTab> {
  String? _sourceId;
  String? _targetId;
  bool _busy = false;

  Future<void> _doMerge() async {
    if (_sourceId == null || _targetId == null) return;
    if (_sourceId == _targetId) {
      _snack('Source and target must be different parties.');
      return;
    }
    final app = context.read<AppProvider>();
    final source = app.partyById(_sourceId!);
    final target = app.partyById(_targetId!);
    if (source == null || target == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Merge'),
        content: Text(
          'All bills from "${source.name}" will be moved to "${target.name}".\n\n'
          '"${source.name}" will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kNavy),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Merge', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    await app.mergeParties(_sourceId!, _targetId!);
    setState(() { _busy = false; _sourceId = null; _targetId = null; });
    _snack('Merged successfully.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final parties = context.watch<AppProvider>().parties;

    return _busy
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              const Text(
                'Merge two parties into one.\nAll bills from the source move to the target, then the source is deleted.',
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              _partyDropdown(
                label: 'Source party (will be deleted)',
                value: _sourceId,
                parties: parties,
                excludeId: _targetId,
                onChanged: (v) => setState(() => _sourceId = v),
              ),
              const SizedBox(height: 8),
              const Center(child: Icon(Icons.arrow_downward, color: kNavy)),
              const SizedBox(height: 8),
              _partyDropdown(
                label: 'Target party (keeps all bills)',
                value: _targetId,
                parties: parties,
                excludeId: _sourceId,
                onChanged: (v) => setState(() => _targetId = v),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_sourceId != null && _targetId != null && _sourceId != _targetId)
                    ? _doMerge
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Merge Parties',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
  }
}

// ── MOVE BILL TAB ────────────────────────────────────────────────────────────

class _MoveBillTab extends StatefulWidget {
  const _MoveBillTab();
  @override
  State<_MoveBillTab> createState() => _MoveBillTabState();
}

class _MoveBillTabState extends State<_MoveBillTab> {
  String? _fromPartyId;
  String? _selectedBillId;
  String? _toPartyId;
  bool _busy = false;

  Future<void> _doMove() async {
    if (_selectedBillId == null || _toPartyId == null) return;
    final app = context.read<AppProvider>();
    final bill = app.billById(_selectedBillId!);
    final toParty = app.partyById(_toPartyId!);
    if (bill == null || toParty == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Move'),
        content: Text('Move Bill #${bill.billNo} to "${toParty.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kNavy),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    await app.moveBill(_selectedBillId!, _toPartyId!);
    setState(() { _busy = false; _selectedBillId = null; _toPartyId = null; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill moved successfully.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final parties = app.parties;

    final fromBills = _fromPartyId != null
        ? app.billsForParty(_fromPartyId!)
        : <Bill>[];

    // Reset selected bill if it no longer belongs to fromParty
    if (_selectedBillId != null &&
        !fromBills.any((b) => b.id == _selectedBillId)) {
      _selectedBillId = null;
    }

    return _busy
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              const Text(
                'Move a single bill from one party to another.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),

              // Step 1: pick source party
              _partyDropdown(
                label: 'From party',
                value: _fromPartyId,
                parties: parties,
                excludeId: _toPartyId,
                onChanged: (v) => setState(() {
                  _fromPartyId = v;
                  _selectedBillId = null;
                }),
              ),
              const SizedBox(height: 16),

              // Step 2: pick bill from that party
              if (_fromPartyId != null) ...[
                _billDropdown(fromBills),
                const SizedBox(height: 16),
              ],

              // Step 3: pick destination party
              if (_selectedBillId != null) ...[
                _partyDropdown(
                  label: 'To party',
                  value: _toPartyId,
                  parties: parties,
                  excludeId: _fromPartyId,
                  onChanged: (v) => setState(() => _toPartyId = v),
                ),
                const SizedBox(height: 32),
              ],

              ElevatedButton(
                onPressed: (_selectedBillId != null && _toPartyId != null) ? _doMove : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Move Bill',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
  }

  Widget _billDropdown(List<Bill> bills) {
    return DropdownButtonFormField<String>(
      value: _selectedBillId,
      decoration: InputDecoration(
        labelText: 'Select bill',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: kInputBg,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('— select bill —')),
        ...bills.map((b) => DropdownMenuItem(
              value: b.id,
              child: Text(
                'Bill #${b.billNo}  ${b.billDate.isNotEmpty ? '· ${fmtDate(b.billDate)}' : ''}  · ${b.entries.length} entries',
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged: (v) => setState(() => _selectedBillId = v),
    );
  }
}

// ── DELETE TAB ───────────────────────────────────────────────────────────────

class _DeleteTab extends StatefulWidget {
  const _DeleteTab();
  @override
  State<_DeleteTab> createState() => _DeleteTabState();
}

class _DeleteTabState extends State<_DeleteTab> {
  String? _partyId;
  bool _busy = false;

  Future<void> _doDelete() async {
    if (_partyId == null) return;
    final app = context.read<AppProvider>();
    final party = app.partyById(_partyId!);
    if (party == null) return;
    final billCount = app.billsForParty(_partyId!).length;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Party'),
        content: Text(
          'Delete "${party.name}" and ALL $billCount bill${billCount == 1 ? '' : 's'}?\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    await app.deleteParty(_partyId!);
    setState(() { _busy = false; _partyId = null; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Party deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final parties = app.parties;

    final billCount = _partyId != null ? app.billsForParty(_partyId!).length : 0;

    return _busy
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  '⚠️  This permanently deletes the party AND all its bills. '
                  'Use Merge instead if you want to keep the bills under a different party.',
                  style: TextStyle(color: Colors.red, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),
              _partyDropdown(
                label: 'Party to delete',
                value: _partyId,
                parties: parties,
                onChanged: (v) => setState(() => _partyId = v),
              ),
              if (_partyId != null) ...[
                const SizedBox(height: 12),
                Text(
                  '$billCount bill${billCount == 1 ? '' : 's'} will be permanently deleted.',
                  style: TextStyle(
                    color: billCount > 0 ? Colors.red : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _partyId != null ? _doDelete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Delete Party & Bills',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
          );
  }
}

// ── Shared dropdown helper ────────────────────────────────────────────────────

Widget _partyDropdown({
  required String label,
  required String? value,
  required List<Party> parties,
  String? excludeId,
  required ValueChanged<String?> onChanged,
}) {
  final filtered = excludeId != null
      ? parties.where((p) => p.id != excludeId).toList()
      : parties;

  return DropdownButtonFormField<String>(
    value: (value != null && filtered.any((p) => p.id == value)) ? value : null,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: kInputBg,
    ),
    items: [
      const DropdownMenuItem(value: null, child: Text('— select —')),
      ...filtered.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
    ],
    onChanged: onChanged,
  );
}
