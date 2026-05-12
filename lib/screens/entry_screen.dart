// lib/screens/entry_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/entry.dart';
import '../models/totals.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'bill_preview_screen.dart';

class EntryScreen extends StatefulWidget {
  final String billId;
  const EntryScreen({super.key, required this.billId});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String _date = todayStr();
  final _awbCtrl = TextEditingController();
  final _kgCtrl = TextEditingController();
  String _mode = 'AIR';
  final _destCtrl = TextEditingController();
  final _clientCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String? _editEntryId;
  String _savedFlash = '';
  String? _awbError;

  // Autocomplete
  List<String> _destSuggestions = [];
  List<String> _clientSuggestions = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _awbCtrl.dispose();
    _kgCtrl.dispose();
    _destCtrl.dispose();
    _clientCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _resetForm({bool keepDateMode = true}) {
    setState(() {
      if (!keepDateMode) _date = todayStr();
      _awbCtrl.clear();
      _kgCtrl.clear();
      _destCtrl.clear();
      _clientCtrl.clear();
      _priceCtrl.clear();
      _editEntryId = null;
      _awbError = null;
      _destSuggestions = [];
      _clientSuggestions = [];
    });
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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
      setState(
          () => _date = picked.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _saveEntry() async {
    final app = context.read<AppProvider>();
    final awb = _awbCtrl.text.trim();
    final dest = _destCtrl.text.trim();
    if (awb.isEmpty || dest.isEmpty) return;

    // Global AWB uniqueness check
    if (app.isDupeAwb(widget.billId, awb, excludeEntryId: _editEntryId)) {
      setState(() => _awbError = '⚠️ AWB already exists in another bill');
      return;
    }

    final entry = Entry(
      id: _editEntryId ?? app.uid(),
      date: _date,
      awb: awb,
      kg: _kgCtrl.text.trim(),
      mode: _mode,
      destination: dest.toUpperCase(),
      clientName: _clientCtrl.text.trim(),
      price: _priceCtrl.text.trim(),
    );

    if (_editEntryId != null) {
      await app.updateEntry(widget.billId, entry);
      setState(() => _savedFlash = '✓ Entry updated!');
    } else {
      await app.addEntry(widget.billId, entry);
      setState(() => _savedFlash = '✓ Entry saved!');
    }

    _resetForm();
    _tabCtrl.animateTo(1);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _savedFlash = '');
  }

  void _startEdit(Entry e) {
    setState(() {
      _editEntryId = e.id;
      _date = e.date.isEmpty ? todayStr() : e.date;
      _awbCtrl.text = e.awb;
      _kgCtrl.text = e.kg;
      _mode = e.mode;
      _destCtrl.text = e.destination;
      _clientCtrl.text = e.clientName;
      _priceCtrl.text = e.price;
      _awbError = null;
      _destSuggestions = [];
      _clientSuggestions = [];
    });
    _tabCtrl.animateTo(0);
  }

  void _onDestChanged(String val) {
    final app = context.read<AppProvider>();
    setState(() {
      _destSuggestions = app.destinationSuggestions(val);
    });
  }

  void _onClientChanged(String val) {
    final app = context.read<AppProvider>();
    setState(() {
      _clientSuggestions = app.clientNameSuggestions(val);
    });
  }

  void _selectDest(String val) {
    _destCtrl.text = val;
    setState(() => _destSuggestions = []);
  }

  void _selectClient(String val) {
    _clientCtrl.text = val;
    setState(() => _clientSuggestions = []);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final bill = app.billById(widget.billId);
    if (bill == null) {
      return Scaffold(
          appBar: AppBar(title: const Text('Bill')),
          body: const Center(child: Text('Bill not found')));
    }
    final party = app.partyById(bill.partyId);
    final entries = bill.entries;
    final totals = Totals.calc(entries, party);

    return Scaffold(
      appBar: AppBar(
        title: Text('Bill #${bill.billNo}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BillPreviewScreen(billId: widget.billId)),
            ),
            child: const Text('Preview / Share',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [Tab(text: 'Add Entry'), Tab(text: 'Entries')],
        ),
      ),
      body: Column(
        children: [
          TotalsStrip(items: [
            _StripItem('ENTRIES', entries.length.toString()),
            _StripItem('GROSS', fmtINR(totals.gross)),
            _StripItem('NET', fmtINR(totals.net)),
          ]),

          if (_savedFlash.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: FlashBar(message: _savedFlash),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _AddEntryTab(
                  date: _date,
                  awbCtrl: _awbCtrl,
                  kgCtrl: _kgCtrl,
                  mode: _mode,
                  destCtrl: _destCtrl,
                  clientCtrl: _clientCtrl,
                  priceCtrl: _priceCtrl,
                  editEntryId: _editEntryId,
                  awbError: _awbError,
                  destSuggestions: _destSuggestions,
                  clientSuggestions: _clientSuggestions,
                  onPickDate: _pickDate,
                  onModeChanged: (m) => setState(() => _mode = m),
                  onSave: _saveEntry,
                  onCancel: _resetForm,
                  onAwbChanged: (_) => setState(() => _awbError = null),
                  onDestChanged: _onDestChanged,
                  onClientChanged: _onClientChanged,
                  onSelectDest: _selectDest,
                  onSelectClient: _selectClient,
                ),
                _EntryListTab(
                  entries: entries,
                  onEdit: _startEdit,
                  onDelete: (eid) async {
                    final e =
                        entries.firstWhere((x) => x.id == eid);
                    final ok = await showConfirmDelete(
                      context,
                      'Delete entry: AWB ${e.awb}?',
                      'This cannot be undone.',
                    );
                    if (ok && context.mounted) {
                      context
                          .read<AppProvider>()
                          .deleteEntry(widget.billId, eid);
                      if (_editEntryId == eid) _resetForm();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Strip item helper ─────────────────────────────────────────────────────────
class _StripItem {
  final String label;
  final String value;
  const _StripItem(this.label, this.value);
}

class TotalsStrip extends StatelessWidget {
  final List<_StripItem> items;
  const TotalsStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavy,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        children: items
            .map((item) => Expanded(
                  child: Column(
                    children: [
                      Text(item.label,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF89AECB),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4)),
                      const SizedBox(height: 2),
                      Text(item.value,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}


// ── Upper-case text formatter ─────────────────────────────────────────────────
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ── Autocomplete field widget ─────────────────────────────────────────────────
class _AutocompleteField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSelect;

  final bool uppercase;

  const _AutocompleteField({
    required this.controller,
    required this.hint,
    required this.suggestions,
    required this.onChanged,
    required this.onSelect,
    this.uppercase = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textCapitalization:
              uppercase ? TextCapitalization.characters : TextCapitalization.words,
          inputFormatters: uppercase ? [_UpperCaseFormatter()] : null,
          onChanged: (v) => onChanged(uppercase ? v.toUpperCase() : v),
          decoration: InputDecoration(hintText: hint),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kInputBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08), blurRadius: 6)
              ],
            ),
            child: Column(
              children: suggestions.map((s) {
                return InkWell(
                  onTap: () => onSelect(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.history, size: 14, color: kMeta),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF1A1A2E))),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Add entry tab ─────────────────────────────────────────────────────────────
class _AddEntryTab extends StatelessWidget {
  final String date;
  final TextEditingController awbCtrl, kgCtrl, destCtrl, clientCtrl, priceCtrl;
  final String mode;
  final String? editEntryId;
  final String? awbError;
  final List<String> destSuggestions;
  final List<String> clientSuggestions;
  final VoidCallback onPickDate;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final ValueChanged<String> onAwbChanged;
  final ValueChanged<String> onDestChanged;
  final ValueChanged<String> onClientChanged;
  final ValueChanged<String> onSelectDest;
  final ValueChanged<String> onSelectClient;

  const _AddEntryTab({
    required this.date,
    required this.awbCtrl,
    required this.kgCtrl,
    required this.mode,
    required this.destCtrl,
    required this.clientCtrl,
    required this.priceCtrl,
    required this.editEntryId,
    required this.awbError,
    required this.destSuggestions,
    required this.clientSuggestions,
    required this.onPickDate,
    required this.onModeChanged,
    required this.onSave,
    required this.onCancel,
    required this.onAwbChanged,
    required this.onDestChanged,
    required this.onClientChanged,
    required this.onSelectDest,
    required this.onSelectClient,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (editEntryId != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kNavy.withOpacity(0.3)),
            ),
            child: const Text('✏️ Editing existing entry',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kNavy)),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 4)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date
              FieldWrap(
                label: 'Date',
                child: GestureDetector(
                  onTap: onPickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: kInputBg,
                      border:
                          Border.all(color: kInputBorder, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(fmtDate(date),
                              style: const TextStyle(
                                  fontSize: 15, color: Color(0xFF1A1A2E))),
                        ),
                        const Icon(Icons.calendar_today,
                            size: 18, color: kNavy),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 13),

              // AWB
              FieldWrap(
                label: 'AWB No *',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: awbCtrl,
                      onChanged: onAwbChanged,
                      decoration: InputDecoration(
                        hintText: 'Airway Bill Number',
                        filled: true,
                        fillColor: awbError != null
                            ? const Color(0xFFFFFBF2)
                            : kInputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: awbError != null
                                  ? const Color(0xFFD97706)
                                  : kInputBorder,
                              width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                              color: awbError != null
                                  ? const Color(0xFFD97706)
                                  : kInputBorder,
                              width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                      ),
                    ),
                    if (awbError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(awbError!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 13),

              // KG
              FieldWrap(
                label: 'Weight (KG)',
                child: TextField(
                  controller: kgCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: '0.0'),
                ),
              ),
              const SizedBox(height: 13),

              // Mode
              FieldWrap(
                label: 'Mode',
                child: ModeToggle(
                  modes: Entry.modes,
                  selected: mode,
                  onChanged: onModeChanged,
                ),
              ),
              const SizedBox(height: 13),

              // Destination with autocomplete
              FieldWrap(
                label: 'Destination *',
                child: _AutocompleteField(
                  controller: destCtrl,
                  hint: 'CITY / LOCATION',
                  suggestions: destSuggestions,
                  onChanged: onDestChanged,
                  onSelect: onSelectDest,
                  uppercase: true,
                ),
              ),
              const SizedBox(height: 13),

              // Client Name with autocomplete
              FieldWrap(
                label: 'Client Name',
                child: _AutocompleteField(
                  controller: clientCtrl,
                  hint: 'Optional',
                  suggestions: clientSuggestions,
                  onChanged: onClientChanged,
                  onSelect: onSelectClient,
                ),
              ),
              const SizedBox(height: 13),

              // Price
              FieldWrap(
                label: 'Amount (₹)',
                child: TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      prefixText: '₹ ', hintText: '0'),
                ),
              ),
              const SizedBox(height: 16),

              if (editEntryId != null)
                Row(children: [
                  Expanded(
                      child: PrimaryBtn(
                          label: 'Update Entry', onTap: onSave)),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                          GhostBtn(label: 'Cancel', onTap: onCancel)),
                ])
              else
                PrimaryBtn(label: '+ Save Entry', onTap: onSave),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Entry list tab ────────────────────────────────────────────────────────────
class _EntryListTab extends StatelessWidget {
  final List<Entry> entries;
  final ValueChanged<Entry> onEdit;
  final ValueChanged<String> onDelete;

  const _EntryListTab({
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const EmptyState(
          icon: '📦',
          text: 'No entries yet',
          hint: 'Switch to Add Entry tab to add one');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final e = entries[i];
        return _EntryCard(
          number: i + 1,
          entry: e,
          onEdit: () => onEdit(e),
          onDelete: () => onDelete(e.id),
        );
      },
    );
  }
}

class _EntryCard extends StatelessWidget {
  final int number;
  final Entry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.number,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final price = double.tryParse(entry.price) ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.07), blurRadius: 3)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('#$number',
                  style: const TextStyle(
                      color: kMeta,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(entry.destination,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Text(fmtINR(price),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kGreen,
                      fontSize: 15)),
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 18, color: kNavy)),
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: kRed)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              if (entry.date.isNotEmpty)
                Text(fmtDate(entry.date),
                    style:
                        const TextStyle(color: kMeta, fontSize: 12)),
              Text('AWB: ${entry.awb}',
                  style: const TextStyle(color: kMeta, fontSize: 12)),
              if (entry.kg.isNotEmpty)
                Text('${entry.kg} kg',
                    style:
                        const TextStyle(color: kMeta, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: kNavyLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(entry.mode,
                    style: const TextStyle(
                        fontSize: 11,
                        color: kNavy,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
