// lib/providers/app_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/party.dart';
import '../models/bill.dart';
import '../models/entry.dart';
import '../models/company_info.dart';

const _storageKey = 'jss-app-v4';
const _uuid = Uuid();

class AppProvider extends ChangeNotifier {
  List<Party> _parties = [];
  List<Bill> _bills = [];
  CompanyInfo _company = CompanyInfo.defaults;
  bool _loaded = false;

  List<Party> get parties => _parties;
  List<Bill> get bills => _bills;
  CompanyInfo get company => _company;
  bool get loaded => _loaded;

  String uid() => _uuid.v4();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _parties = ((data['parties'] as List?) ?? [])
            .map((p) => Party.fromJson(p as Map<String, dynamic>))
            .toList();
        _bills = ((data['bills'] as List?) ?? [])
            .map((b) => Bill.fromJson(b as Map<String, dynamic>))
            .toList();
        if (data['company'] != null) {
          _company = CompanyInfo.fromJson(data['company'] as Map<String, dynamic>);
        }
      } catch (_) {
        _parties = Party.defaults;
        _bills = [];
        _company = CompanyInfo.defaults;
      }
    } else {
      _parties = Party.defaults;
      _bills = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({
        'parties': _parties.map((p) => p.toJson()).toList(),
        'bills': _bills.map((b) => b.toJson()).toList(),
        'company': _company.toJson(),
      }),
    );
  }

  // ── Company Info ──────────────────────────────────────────────────────────────

  Future<void> updateCompany(CompanyInfo updated) async {
    _company = updated;
    notifyListeners();
    await _save();
  }

  // ── Parties ──────────────────────────────────────────────────────────────────

  Party? partyById(String id) {
    try {
      return _parties.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  bool isDupePartyName(String name, {String? excludeId}) {
    return _parties.any((p) =>
        p.id != excludeId &&
        p.name.trim().toLowerCase() == name.trim().toLowerCase());
  }

  Future<bool> addParty(String name) async {
    if (isDupePartyName(name)) return false;
    _parties.add(Party(
      id: uid(),
      name: name.trim(),
    ));
    notifyListeners();
    await _save();
    return true;
  }

  Future<bool> updateParty(Party updated) async {
    if (isDupePartyName(updated.name, excludeId: updated.id)) return false;
    final idx = _parties.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return false;
    _parties[idx] = updated;
    notifyListeners();
    await _save();
    return true;
  }

  // ── Bills ─────────────────────────────────────────────────────────────────────

  List<Bill> billsForParty(String partyId) {
    final list = _bills.where((b) => b.partyId == partyId).toList();
    list.sort((a, b) {
      final da = a.billDate, db = b.billDate;
      if (db != da) return db.compareTo(da);
      return b.createdAt - a.createdAt;
    });
    return list;
  }

  /// Bill number is unique globally across all parties.
  bool isDupeBillNo(String partyId, String billNo, {String? excludeId}) {
    final norm = billNo.trim().toLowerCase();
    return _bills.any((b) =>
        b.id != excludeId &&
        b.billNo.trim().toLowerCase() == norm);
  }

  Future<Bill?> createBill(String partyId, String billNo, String billDate) async {
    if (isDupeBillNo(partyId, billNo)) return null;
    final bill = Bill(
      id: uid(),
      partyId: partyId,
      billNo: billNo.trim(),
      billDate: billDate,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _bills.insert(0, bill);
    notifyListeners();
    await _save();
    return bill;
  }

  Future<void> deleteBill(String billId) async {
    _bills.removeWhere((b) => b.id == billId);
    notifyListeners();
    await _save();
  }

  Bill? billById(String billId) {
    try {
      return _bills.firstWhere((b) => b.id == billId);
    } catch (_) {
      return null;
    }
  }

  // ── Entries ────────────────────────────────────────────────────────────────────

  Future<void> addEntry(String billId, Entry entry) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    _bills[idx].entries.add(entry);
    notifyListeners();
    await _save();
  }

  Future<void> updateEntry(String billId, Entry updated) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final eIdx = _bills[idx].entries.indexWhere((e) => e.id == updated.id);
    if (eIdx == -1) return;
    _bills[idx].entries[eIdx] = updated;
    notifyListeners();
    await _save();
  }

  Future<void> deleteEntry(String billId, String entryId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    _bills[idx].entries.removeWhere((e) => e.id == entryId);
    notifyListeners();
    await _save();
  }

  /// AWB is unique globally across ALL bills.
  bool isDupeAwb(String billId, String awb, {String? excludeEntryId}) {
    final norm = awb.trim().toLowerCase();
    for (final bill in _bills) {
      for (final e in bill.entries) {
        if (e.id == excludeEntryId) continue;
        if (e.awb.trim().toLowerCase() == norm) return true;
      }
    }
    return false;
  }

  // ── Autocomplete suggestions ───────────────────────────────────────────────

  List<String> destinationSuggestions(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final seen = <String>{};
    final results = <String>[];
    for (final bill in _bills) {
      for (final e in bill.entries) {
        final dest = e.destination.trim();
        if (dest.isNotEmpty &&
            dest.toLowerCase().startsWith(q) &&
            seen.add(dest.toLowerCase())) {
          results.add(dest);
        }
      }
    }
    results.sort();
    return results.take(6).toList();
  }

  List<String> clientNameSuggestions(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final seen = <String>{};
    final results = <String>[];
    for (final bill in _bills) {
      for (final e in bill.entries) {
        final name = e.clientName.trim();
        if (name.isNotEmpty &&
            name.toLowerCase().startsWith(q) &&
            seen.add(name.toLowerCase())) {
          results.add(name);
        }
      }
    }
    results.sort();
    return results.take(6).toList();
  }
}
