// lib/screens/bill_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/bill.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../models/totals.dart';
import '../widgets/common_widgets.dart';
import 'entry_screen.dart';

class BillListScreen extends StatefulWidget {
  final String partyId;
  const BillListScreen({super.key, required this.partyId});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  bool _showNewBill = false;
  final _billNoCtrl = TextEditingController();
  final _billDateCtrl = TextEditingController();
  String _billDate = todayStr();
  String? _dupeError;
  late int _fy; // financial year for the new bill

  @override
  void initState() {
    super.initState();
    _billDateCtrl.text = fmtDate(todayStr());
    _fy = currentFY();
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _billDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kNavy),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _billDate = picked.toIso8601String().split('T')[0];
        _billDateCtrl.text = fmtDate(_billDate);
        _fy = fyOfDate(_billDate);
      });
    }
  }

  Future<void> _createBill() async {
    final app = context.read<AppProvider>();
    final billNo = _billNoCtrl.text.trim();
    if (billNo.isEmpty) return;
    if (app.isDupeBillNo(widget.partyId, billNo, fy: _fy)) {
      setState(() => _dupeError =
          '⚠️ Bill $_fy/$billNo already exists for this year');
      return;
    }
    final bill = await app.createBill(widget.partyId, billNo, _billDate);
    if (bill != null && mounted) {
      setState(() {
        _showNewBill = false;
        _billNoCtrl.clear();
        _dupeError = null;
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EntryScreen(billId: bill.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final party = app.partyById(widget.partyId);
    final focusBills = app.billsForParty(widget.partyId);

    return Scaffold(
      appBar: AppBar(
        title: Text(party?.name ?? 'Bills'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() {
              _showNewBill = !_showNewBill;
              _dupeError = null;
            }),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('New Bill',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_showNewBill) _NewBillCard(
            billNoCtrl: _billNoCtrl,
            billDateCtrl: _billDateCtrl,
            dupeError: _dupeError,
            fy: _fy,
            onPickDate: _pickDate,
            onCancel: () => setState(() {
              _showNewBill = false;
              _dupeError = null;
            }),
            onCreate: _createBill,
            onChanged: (_) => setState(() => _dupeError = null),
            onFyChanged: (y) => setState(() {
              _fy = y;
              _dupeError = null;
            }),
          ),
          if (focusBills.isEmpty && !_showNewBill)
            const EmptyState(
              icon: '🧾',
              text: 'No bills yet',
              hint: 'Tap + New Bill to create one',
            )
          else
            ...focusBills.map((bill) {
              final totals = Totals.calc(bill.entries, party);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BillCard(
                  bill: bill,
                  totals: totals,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EntryScreen(billId: bill.id)),
                  ),
                  onDelete: () async {
                    final ok = await showConfirmDelete(
                      context,
                      'Delete Bill ${fyOfDate(bill.billDate)}/${bill.billNo}?',
                      'This will permanently remove all ${bill.entries.length} '
                          'entr${bill.entries.length == 1 ? 'y' : 'ies'} inside it.',
                    );
                    if (ok && context.mounted) {
                      context.read<AppProvider>().deleteBill(bill.id);
                    }
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── New bill form card ────────────────────────────────────────────────────────
class _NewBillCard extends StatelessWidget {
  final TextEditingController billNoCtrl;
  final TextEditingController billDateCtrl;
  final String? dupeError;
  final int fy;
  final VoidCallback onPickDate;
  final VoidCallback onCancel;
  final VoidCallback onCreate;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onFyChanged;

  const _NewBillCard({
    required this.billNoCtrl,
    required this.billDateCtrl,
    required this.dupeError,
    required this.fy,
    required this.onPickDate,
    required this.onCancel,
    required this.onCreate,
    required this.onChanged,
    required this.onFyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kNavy, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 New Bill',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                  fontSize: 14)),
          const SizedBox(height: 12),
          FieldWrap(
            label: 'Bill Number',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FY prefix badge + number input on one row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // FY selector — tap arrows to go forward/back
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDialog<int>(
                          context: context,
                          builder: (_) => _FyPickerDialog(currentFy: fy),
                        );
                        if (picked != null) onFyChanged(picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 11),
                        decoration: BoxDecoration(
                          color: kNavy,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => onFyChanged(fy - 1),
                              child: const Icon(Icons.chevron_left,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 2),
                            Text('$fy',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const SizedBox(width: 2),
                            GestureDetector(
                              onTap: () => onFyChanged(fy + 1),
                              child: const Icon(Icons.chevron_right,
                                  color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: kNavy.withOpacity(0.7),
                      ),
                      child: const Text(' / ',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: billNoCtrl,
                        onChanged: onChanged,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'e.g. 01',
                          filled: true,
                          fillColor: dupeError != null
                              ? const Color(0xFFFFFBF2)
                              : kInputBg,
                          border: OutlineInputBorder(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            borderSide: BorderSide(
                                color: dupeError != null
                                    ? const Color(0xFFD97706)
                                    : kInputBorder,
                                width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            borderSide: BorderSide(
                                color: dupeError != null
                                    ? const Color(0xFFD97706)
                                    : kInputBorder,
                                width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                if (dupeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(dupeError!,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB45309),
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FieldWrap(
            label: 'Bill Date',
            child: GestureDetector(
              onTap: onPickDate,
              child: AbsorbPointer(
                child: TextField(
                  controller: billDateCtrl,
                  decoration: InputDecoration(
                    suffixIcon:
                        const Icon(Icons.calendar_today, size: 18, color: kNavy),
                    filled: true,
                    fillColor: kInputBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kInputBorder, width: 1.5)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kInputBorder, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: PrimaryBtn(label: 'Create Bill', onTap: onCreate)),
              const SizedBox(width: 8),
              Expanded(child: GhostBtn(label: 'Cancel', onTap: onCancel)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Bill card ─────────────────────────────────────────────────────────────────
class _BillCard extends StatelessWidget {
  final Bill bill;
  final Totals totals;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BillCard({
    required this.bill,
    required this.totals,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: kCardBorder, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill ${fyOfDate(bill.billDate)}/${bill.billNo}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kNavy)),
                    const SizedBox(height: 3),
                    Text(
                      '${fmtDate(bill.billDate)} · ${bill.entries.length} entr${bill.entries.length == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(fontSize: 12, color: kMeta),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Net: ${fmtINR2(totals.net)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kGreen),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete bill',
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── FY picker dialog ─────────────────────────────────────────────────────────
class _FyPickerDialog extends StatefulWidget {
  final int currentFy;
  const _FyPickerDialog({required this.currentFy});

  @override
  State<_FyPickerDialog> createState() => _FyPickerDialogState();
}

class _FyPickerDialogState extends State<_FyPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentFy;
  }

  @override
  Widget build(BuildContext context) {
    // Show a window of 5 years: 2 before current FY, current, 2 after
    final base = currentFY();
    final years = List.generate(7, (i) => base - 3 + i); // base-3 to base+3

    return AlertDialog(
      title: const Text('Select Financial Year',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: kNavy)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('FY ending year (Apr–Mar)',
              style: TextStyle(fontSize: 12, color: kMeta)),
          const SizedBox(height: 10),
          ...years.map((y) {
            final isSelected = y == _selected;
            final isCurrent  = y == base;
            return GestureDetector(
              onTap: () => setState(() => _selected = y),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? kNavy : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? kNavy : kInputBorder,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Text('FY $y  (${y - 1}–$y)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                        )),
                    const Spacer(),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withOpacity(0.25)
                              : kNavy.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Current',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : kNavy,
                            )),
                      ),
                    if (isSelected && !isCurrent)
                      Icon(Icons.check, size: 16,
                          color: isSelected ? Colors.white : kNavy),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kNavy),
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Select',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
