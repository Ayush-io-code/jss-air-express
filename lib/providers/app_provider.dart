// lib/providers/app_provider.dart
//
// Sync behaviour:
//   • App launch          → pull from Drive + merge (once).
//   • App in foreground   → poll Drive every 4 seconds (pull + merge if changed).
//   • App backgrounded    → timer paused, no network calls.
//   • App foregrounded    → timer resumes immediately with a fresh pull.
//   • Entry/bill saved    → push to Drive instantly (in addition to polling).
//
// The poll is lightweight: Drive returns the file's modifiedTime first (cheap
// metadata call). We only download + merge when that timestamp has changed,
// so if nobody else has touched the data the poll costs one tiny request every
// 4 seconds — no wasted bandwidth.
//
// Soft-delete (tombstoning):
//   Deleted bill/entry IDs are stored in _deletedBillIds / _deletedEntryIds.
//   These sets are included in the encoded JSON and merged across devices.
//   During merge, any ID present in the deleted sets is never resurrected —
//   fixing the "resurrection bug" where a delete on one device was undone by
//   a sync from another device that still had the item.
//
// Last-write-wins for entry updates:
//   Each Entry carries an updatedAt timestamp. During merge, if both devices
//   have the same entry ID, the version with the higher updatedAt wins —
//   so edits (price, clientName, destination, etc.) propagate correctly.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/party.dart';
import '../models/bill.dart';
import '../models/entry.dart';
import '../models/company_info.dart';
import '../services/drive_sync_service.dart';
import '../utils/helpers.dart';

const _storageKey   = 'jss-app-v4';
const _pollInterval = Duration(seconds: 4);
const _uuid         = Uuid();

enum SyncStatus { idle, syncing, done, error }

class AppProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<Party>  _parties = [];
  List<Bill>   _bills   = [];
  CompanyInfo  _company = CompanyInfo.defaults;
  bool         _loaded  = false;

  SyncStatus _syncStatus = SyncStatus.idle;
  DateTime?  _lastSync;
  String?    _syncError;

  SyncStatus get syncStatus => _syncStatus;
  DateTime?  get lastSync   => _lastSync;
  String?    get syncError  => _syncError;
  List<Party>  get parties  => _parties;
  List<Bill>   get bills    => _bills;
  CompanyInfo  get company  => _company;
  bool         get loaded   => _loaded;

  Timer?  _pollTimer;
  bool    _pollBusy         = false;
  String? _lastKnownVersion;      // Drive modifiedTime; skips download if unchanged

  final Set<String> _deletedBillIds   = {};   // soft-delete tombstones
  final Set<String> _deletedEntryIds  = {};

  String uid() => _uuid.v4();

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    WidgetsBinding.instance.addObserver(this);
    await _loadLocal();
    _loaded = true;
    notifyListeners();

    if (DriveSyncService.instance.isSignedIn) {
      await _pullAndMerge();
      _startPolling();
    }
  }

  // Called from SyncButton after the user signs in.
  Future<void> onSignedIn() async {
    await _pullAndMerge();
    _startPolling();
  }

  // Called from SyncButton when the user signs out.
  void onSignedOut() {
    _stopPolling();
    _lastKnownVersion = null;
    _setSyncStatus(SyncStatus.idle);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  // ── App lifecycle ──────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!DriveSyncService.instance.isSignedIn) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _pullAndMerge();      // immediate pull when foregrounded
        _startPolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopPolling();       // no calls when backgrounded
        break;
    }
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollTick());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollTick() async {
    if (_pollBusy || !DriveSyncService.instance.isSignedIn) return;
    _pollBusy = true;
    try {
      // Cheap metadata check first — only download if something changed.
      final version = await DriveSyncService.instance.fetchVersion();
      if (version == null || version == _lastKnownVersion) return;
      await _pullAndMerge();
    } finally {
      _pollBusy = false;
    }
  }

  // ── Manual sync ────────────────────────────────────────────────────────────

  Future<void> manualSync() async {
    if (!DriveSyncService.instance.isSignedIn) return;
    await _pullAndMerge();
  }

  // ── Local load ─────────────────────────────────────────────────────────────

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _parties = Party.defaults;
        _bills   = [];
        _company = CompanyInfo.defaults;
      }
    } else {
      _parties = Party.defaults;
      _bills   = [];
    }
  }

  // ── Save (local + push) ────────────────────────────────────────────────────

  Future<void> _save() async {
    final encoded = _encode();
    final prefs   = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, encoded);

    if (DriveSyncService.instance.isSignedIn) {
      _setSyncStatus(SyncStatus.syncing);
      final newVersion = await DriveSyncService.instance.push(encoded);
      if (newVersion != null) {
        _lastKnownVersion = newVersion;   // poll will skip next tick
        _setSyncStatus(SyncStatus.done);
      } else {
        _setSyncStatus(SyncStatus.error, error: 'Upload failed');
      }
    }
  }

  // ── Pull & merge ───────────────────────────────────────────────────────────

  Future<void> _pullAndMerge() async {
    _setSyncStatus(SyncStatus.syncing);
    try {
      final result = await DriveSyncService.instance.pullWithVersion();

      if (result == null) {
        // No remote file yet — first device to use the app. Push local up.
        final v = await DriveSyncService.instance.push(_encode());
        if (v != null) _lastKnownVersion = v;
        _setSyncStatus(SyncStatus.done);
        return;
      }

      final (remoteJson, remoteVersion) = result;
      _lastKnownVersion = remoteVersion;

      _merge(jsonDecode(remoteJson) as Map<String, dynamic>);

      final merged = _encode();
      final prefs  = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, merged);

      final v = await DriveSyncService.instance.push(merged);
      if (v != null) _lastKnownVersion = v;

      _setSyncStatus(SyncStatus.done);
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] sync error: $e');
      _setSyncStatus(SyncStatus.error, error: e.toString());
    }
  }

  // ── Merge ──────────────────────────────────────────────────────────────────

  void _merge(Map<String, dynamic> remoteData) {
    // Parties — union by ID, local wins on conflict
    final remoteParties = ((remoteData['parties'] as List?) ?? [])
        .map((p) => Party.fromJson(p as Map<String, dynamic>))
        .toList();
    final partyMap = <String, Party>{for (final p in _parties) p.id: p};
    for (final rp in remoteParties) {
      partyMap.putIfAbsent(rp.id, () => rp);
    }
    _parties = partyMap.values.toList();

    // Bills + entries — union by ID, respect soft deletes + last-write-wins
    final remoteDeletedBills   = Set<String>.from((remoteData['deletedBills']   as List?) ?? []);
    final remoteDeletedEntries = Set<String>.from((remoteData['deletedEntries'] as List?) ?? []);

    // Merge deleted ID sets with local
    _deletedBillIds.addAll(remoteDeletedBills);
    _deletedEntryIds.addAll(remoteDeletedEntries);

    final remoteBills = ((remoteData['bills'] as List?) ?? [])
        .map((b) => Bill.fromJson(b as Map<String, dynamic>))
        .toList();
    final billMap = <String, Bill>{
      for (final b in _bills)
        if (!_deletedBillIds.contains(b.id)) b.id: b
    };
    for (final rb in remoteBills) {
      if (_deletedBillIds.contains(rb.id)) continue;   // deleted — never resurrect
      if (!billMap.containsKey(rb.id)) {
        billMap[rb.id] = rb;
      } else {
        final local    = billMap[rb.id]!;
        final entryMap = <String, Entry>{
          for (final e in local.entries)
            if (!_deletedEntryIds.contains(e.id)) e.id: e
        };
        for (final re in rb.entries) {
          if (_deletedEntryIds.contains(re.id)) continue;  // deleted — never resurrect
          if (!entryMap.containsKey(re.id)) {
            entryMap[re.id] = re;
          } else {
            // Last-write-wins: keep whichever version was edited more recently
            final localEntry = entryMap[re.id]!;
            if (re.updatedAt > localEntry.updatedAt) {
              entryMap[re.id] = re;
            }
          }
        }
        local.entries
          ..clear()
          ..addAll(entryMap.values);
      }
    }
    _bills = billMap.values.toList();

    // Company — remote wins (most-recently-written device)
    if (remoteData['company'] != null) {
      try {
        _company = CompanyInfo.fromJson(
            remoteData['company'] as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _applyJson(Map<String, dynamic> data) {
    _deletedBillIds
      ..clear()
      ..addAll(((data['deletedBills'] as List?) ?? []).cast<String>());
    _deletedEntryIds
      ..clear()
      ..addAll(((data['deletedEntries'] as List?) ?? []).cast<String>());

    _parties = ((data['parties'] as List?) ?? [])
        .map((p) => Party.fromJson(p as Map<String, dynamic>))
        .toList();
    _bills = ((data['bills'] as List?) ?? [])
        .map((b) => Bill.fromJson(b as Map<String, dynamic>))
        .where((b) => !_deletedBillIds.contains(b.id))
        .toList();
    if (data['company'] != null) {
      _company = CompanyInfo.fromJson(data['company'] as Map<String, dynamic>);
    }
  }

  String _encode() => jsonEncode({
        'parties':        _parties.map((p) => p.toJson()).toList(),
        'bills':          _bills.map((b) => b.toJson()).toList(),
        'company':        _company.toJson(),
        'deletedBills':   _deletedBillIds.toList(),
        'deletedEntries': _deletedEntryIds.toList(),
      });

  void _setSyncStatus(SyncStatus s, {String? error}) {
    _syncStatus = s;
    _syncError  = error;
    if (s == SyncStatus.done) _lastSync = DateTime.now();
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // All original AppProvider methods — unchanged
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> updateCompany(CompanyInfo updated) async {
    _company = updated;
    notifyListeners();
    await _save();
  }

  Party? partyById(String id) {
    try { return _parties.firstWhere((p) => p.id == id); }
    catch (_) { return null; }
  }

  bool isDupePartyName(String name, {String? excludeId}) => _parties.any((p) =>
      p.id != excludeId &&
      p.name.trim().toLowerCase() == name.trim().toLowerCase());

  Future<bool> addParty(String name) async {
    if (isDupePartyName(name)) return false;
    _parties.add(Party(id: uid(), name: name.trim()));
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

  List<Bill> billsForParty(String partyId) {
    final list = _bills.where((b) => b.partyId == partyId).toList();
    list.sort((a, b) {
      final da = a.billDate, db = b.billDate;
      if (db != da) return db.compareTo(da);
      return b.createdAt - a.createdAt;
    });
    return list;
  }

  bool isDupeBillNo(String partyId, String billNo,
      {String? excludeId, int? fy}) {
    final norm = billNo.trim().toLowerCase();
    final checkFY = fy ?? currentFY();
    return _bills.any((b) =>
        b.partyId == partyId &&
        b.id != excludeId &&
        fyOfDate(b.billDate) == checkFY &&
        b.billNo.trim().toLowerCase() == norm);
  }

  Future<Bill?> createBill(String partyId, String billNo, String billDate) async {
    if (isDupeBillNo(partyId, billNo, fy: fyOfDate(billDate))) return null;
    final bill = Bill(
      id: uid(), partyId: partyId, billNo: billNo.trim(),
      billDate: billDate, createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _bills.insert(0, bill);
    notifyListeners();
    await _save();
    return bill;
  }

  /// Import a bill (with its entries) that came from an Excel file.
  /// Skips silently if the bill number already exists.
  Future<bool> importBill({
    required String partyId,
    required String billNo,
    required String billDate,
    required List<Entry> entries,
  }) async {
    if (isDupeBillNo(partyId, billNo)) return false;
    final bill = Bill(
      id:        uid(),
      partyId:   partyId,
      billNo:    billNo.trim(),
      billDate:  billDate,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      entries:   entries,
    );
    _bills.insert(0, bill);
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> deleteBill(String billId) async {
    _deletedBillIds.add(billId);
    _bills.removeWhere((b) => b.id == billId);
    notifyListeners();
    await _save();
  }

  /// Update the bill number and/or date of an existing bill.
  /// Returns false if the new billNo already exists for this party (dupe check).
  Future<bool> updateBillMeta(
      String billId, String newBillNo, String newBillDate) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return false;
    final bill = _bills[idx];
    final trimmed = newBillNo.trim();
    // Only check for duplicate if the bill number actually changed.
    if (trimmed.toLowerCase() != bill.billNo.trim().toLowerCase()) {
      if (isDupeBillNo(bill.partyId, trimmed,
          excludeId: billId, fy: fyOfDate(newBillDate))) return false;
    }
    bill.billNo   = trimmed;
    bill.billDate = newBillDate;
    notifyListeners();
    await _save();
    return true;
  }

  /// Delete a party and ALL its bills permanently.
  Future<void> deleteParty(String partyId) async {
    final partyBillIds = _bills
        .where((b) => b.partyId == partyId)
        .map((b) => b.id)
        .toList();
    _deletedBillIds.addAll(partyBillIds);
    _bills.removeWhere((b) => b.partyId == partyId);
    _parties.removeWhere((p) => p.id == partyId);
    notifyListeners();
    await _save();
  }

  /// Merge [sourceId] into [targetId]: all bills move to target, source deleted.
  Future<void> mergeParties(String sourceId, String targetId) async {
    for (final bill in _bills) {
      if (bill.partyId == sourceId) bill.partyId = targetId;
    }
    _parties.removeWhere((p) => p.id == sourceId);
    notifyListeners();
    await _save();
  }

  /// Move a single bill to a different party.
  Future<void> moveBill(String billId, String newPartyId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    _bills[idx].partyId = newPartyId;
    notifyListeners();
    await _save();
  }

  /// Import a full party (by name) with all its bills from a ZIP.
  /// If a party with that name already exists its id is reused.
  /// Returns the number of bills actually imported (skipping dupes).
  Future<int> importPartyWithBills({
    required String partyName,
    required List<({String billNo, String billDate, List<Entry> entries})> bills,
    String address = '',
    String gstin = '',
    String phone = '',
  }) async {
    String partyId;
    final existing = _parties.where((p) =>
        p.name.trim().toLowerCase() == partyName.trim().toLowerCase());
    if (existing.isNotEmpty) {
      partyId = existing.first.id;
      // Optionally fill in address fields if blank
      final idx = _parties.indexWhere((p) => p.id == partyId);
      if (idx != -1) {
        final p = _parties[idx];
        if (p.address.isEmpty && address.isNotEmpty) {
          _parties[idx] = p.copyWith(address: address);
        }
        if (p.gstin.isEmpty && gstin.isNotEmpty) {
          _parties[idx] = _parties[idx].copyWith(gstin: gstin);
        }
        if (p.phone.isEmpty && phone.isNotEmpty) {
          _parties[idx] = _parties[idx].copyWith(phone: phone);
        }
      }
    } else {
      partyId = uid();
      _parties.add(Party(
        id: partyId,
        name: partyName.trim(),
        address: address,
        gstin: gstin,
        phone: phone,
      ));
    }

    int count = 0;
    for (final b in bills) {
      if (isDupeBillNo(partyId, b.billNo)) continue;
      _bills.insert(0, Bill(
        id:        uid(),
        partyId:   partyId,
        billNo:    b.billNo.trim(),
        billDate:  b.billDate,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        entries:   b.entries,
      ));
      count++;
    }
    notifyListeners();
    await _save();
    return count;
  }

  Bill? billById(String billId) {
    try { return _bills.firstWhere((b) => b.id == billId); }
    catch (_) { return null; }
  }

  Future<void> addEntry(String billId, Entry entry) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    _bills[idx].entries.add(entry);
    _bills[idx].entries.sort(_entryDateCmp);
    notifyListeners();
    await _save();
  }

  Future<void> updateEntry(String billId, Entry updated) async {
    final idx  = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final eIdx = _bills[idx].entries.indexWhere((e) => e.id == updated.id);
    if (eIdx == -1) return;
    // Stamp updatedAt so other devices know this version is newer
    _bills[idx].entries[eIdx] = updated.copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch);
    _bills[idx].entries.sort(_entryDateCmp);
    notifyListeners();
    await _save();
  }

  Future<void> deleteEntry(String billId, String entryId) async {
    _deletedEntryIds.add(entryId);
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    _bills[idx].entries.removeWhere((e) => e.id == entryId);
    notifyListeners();
    await _save();
  }

  // Sort entries ascending by date (empty dates go last)
  static int _entryDateCmp(Entry a, Entry b) {
    if (a.date.isEmpty && b.date.isEmpty) return 0;
    if (a.date.isEmpty) return 1;
    if (b.date.isEmpty) return -1;
    return a.date.compareTo(b.date);
  }

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

  List<String> destinationSuggestions(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    final seen = <String>{};
    final results = <String>[];
    for (final bill in _bills) {
      for (final e in bill.entries) {
        final dest = e.destination.trim();
        if (dest.isNotEmpty && dest.toLowerCase().startsWith(q) &&
            seen.add(dest.toLowerCase())) results.add(dest);
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
        if (name.isNotEmpty && name.toLowerCase().startsWith(q) &&
            seen.add(name.toLowerCase())) results.add(name);
      }
    }
    results.sort();
    return results.take(6).toList();
  }
}
