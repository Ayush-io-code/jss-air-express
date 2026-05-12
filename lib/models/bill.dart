// lib/models/bill.dart
import 'entry.dart';

class Bill {
  final String id;
  final String partyId;
  String billNo;
  String billDate;
  final int createdAt;
  List<Entry> entries;

  Bill({
    required this.id,
    required this.partyId,
    required this.billNo,
    required this.billDate,
    required this.createdAt,
    List<Entry>? entries,
  }) : entries = entries ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'partyId': partyId,
        'billNo': billNo,
        'billDate': billDate,
        'createdAt': createdAt,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'] as String,
        partyId: j['partyId'] as String,
        billNo: j['billNo'] as String,
        billDate: j['billDate'] as String? ?? '',
        createdAt: j['createdAt'] as int? ?? 0,
        entries: ((j['entries'] as List?) ?? [])
            .map((e) => Entry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
