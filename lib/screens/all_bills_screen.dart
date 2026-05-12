// lib/screens/all_bills_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/bill.dart';
import '../models/totals.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/common_widgets.dart';
import 'entry_screen.dart';

class AllBillsScreen extends StatelessWidget {
  const AllBillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bills = [...app.bills];

    // Sort by date desc then createdAt desc
    bills.sort((a, b) {
      final da = a.billDate, db = b.billDate;
      if (db != da) return db.compareTo(da);
      return b.createdAt - a.createdAt;
    });

    // Group by month
    final Map<String, List<Bill>> grouped = {};
    for (final b in bills) {
      final key = monthOf(b.billDate);
      grouped.putIfAbsent(key, () => []).add(b);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('All Bills')),
      body: bills.isEmpty
          ? const EmptyState(
              icon: '🧾',
              text: 'No bills yet',
              hint: 'Create a bill from a party')
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                for (final key in keys) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: SectionLabel(monthLabel(key)),
                  ),
                  for (final bill in grouped[key]!) ...[
                    _AllBillCard(bill: bill, app: app),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
    );
  }
}

class _AllBillCard extends StatelessWidget {
  final Bill bill;
  final AppProvider app;
  const _AllBillCard({required this.bill, required this.app});

  @override
  Widget build(BuildContext context) {
    final party = app.partyById(bill.partyId);
    final totals = Totals.calc(bill.entries, party);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EntryScreen(billId: bill.id)),
        ),
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
                    Text(party?.name ?? '—',
                        style: const TextStyle(
                            fontSize: 13,
                            color: kMeta,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Bill #${bill.billNo}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: kNavy)),
                    const SizedBox(height: 3),
                    Text(
                      '${fmtDate(bill.billDate)} · ${bill.entries.length} entr${bill.entries.length == 1 ? 'y' : 'ies'}',
                      style:
                          const TextStyle(fontSize: 12, color: kMeta),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtINR2(totals.net),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: kGreen,
                          fontSize: 14)),
                  const Text('NET',
                      style: TextStyle(fontSize: 10, color: kMeta)),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB)),
            ],
          ),
        ),
      ),
    );
  }
}
